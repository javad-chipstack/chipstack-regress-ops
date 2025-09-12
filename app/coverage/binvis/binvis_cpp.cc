/// C++ version of binvis - iterates through all covergroup definitions
/// and instances and displays coverage information for every bin.
/// This version generates the same output as the original binvis.

#include "covdb_user.h"
#include "visit.hh"
#include <iostream>
#include <iomanip>

class GroupVisCpp : public UcapiVisitor {
private:
    bool _warned;
    
    void indent(int depth) {
        for(int i = 0; i < depth; i++) std::cout << "..";
    }

    void showBin(int depth, covdbHandle bin, covdbHandle reghdl, bool isAuto, bool isCross) {
        indent(depth);
        std::cout << "(" << ucapiObjTypeName(bin, reghdl) << ") ";

        int ed = covdb_get(bin, reghdl, getTest(), covdbCovered);
        int ab = covdb_get(bin, reghdl, getTest(), covdbCoverable);
        int ct = covdb_get(bin, reghdl, getTest(), covdbCovCount);
        std::cout << ed << "/" << ab << " (count " << ct << ")";
        std::cout << " " << covdb_get_str(bin, covdbName) << " ";
        
        if (isAuto) {
            std::cout << "[auto] (" << covdb_get_str(bin, covdbValueName) << ") ";
        } else {
            std::cout << "[user]";
        }

        covdbObjTypesT ty = (covdbObjTypesT)covdb_get(bin, reghdl, NULL, covdbType);
        bool first = true;
        
        if (covdbBlock == ty) {
            covdbHandle cm, cs = covdb_iterate(bin, covdbObjects);
            while((cm = covdb_scan(cs))) {
                if (first) { std::cout << "\n"; first = false; }
                showBin(depth+1, cm, reghdl, isAuto, isCross);
            }
            covdb_release_handle(cs);
        } else if (covdbCross == ty) {
            covdbHandle cmp, cmps = covdb_iterate(bin, covdbComponents);
            std::cout << "\n"; 
            indent(depth+1); 
            std::cout << "Components:";
            while((cmp = covdb_scan(cmps))) {
                if (first) { std::cout << "\n"; first = false; }
                showBin(depth+2, cmp, reghdl, isAuto, isCross);
            }
            covdb_release_handle(cmps);
            std::cout << "\n"; 
            indent(depth+1); 
            std::cout << "Objects:";
            first = true;
            covdbHandle k, ks = covdb_iterate(bin, covdbObjects);
            while((k = covdb_scan(ks))) {
                if (first) { std::cout << "\n"; first = false; }
                showBin(depth+2, k, reghdl, isAuto, isCross);
            }
            if (first) std::cout << "NONE";
            covdb_release_handle(ks);
        } else if (covdbValueSet == ty) {
            covdbHandle kid, kids = covdb_iterate(bin, covdbObjects);
            first = true;
            while((kid = covdb_scan(kids))) {
                if (first) { std::cout << "\n"; first = false; }
                showBin(depth+1, kid, reghdl, isAuto, isCross);
            }
            covdb_release_handle(kids);
        } else if (covdbIntervalValue == ty) {
            // Handle interval values - these are leaf nodes, no recursion needed
        } else if (covdbIntegerValue == ty) {
            // Handle integer values - these are leaf nodes, no recursion needed
        } else if (covdbScalarValue == ty) {
            // Handle scalar values - these are leaf nodes, no recursion needed
        } else if (covdbVectorValue == ty) {
            // Handle vector values - these are leaf nodes, no recursion needed
        } else if (covdbBDDValue == ty) {
            // Handle BDD values - these are leaf nodes, no recursion needed
        }
        std::cout << "\n";
    }

    /// iterate all coverpoints and crosses (and their bins) from a
    /// testbench-qualified instance or definition handle
    void iterateGroupObjects(covdbHandle reghdl) {
        covdbHandle cpcr, cpcrs = covdb_iterate(reghdl, covdbObjects);
        while((cpcr = covdb_scan(cpcrs))) {
            const char* ann = covdb_get_annotation(cpcr, IS_CROSS);
            bool isCross = (*ann == '1');
            std::cout << " " << (isCross ? "cross" : "coverpoint") << " " 
                      << covdb_get_str(cpcr, covdbName)
                      << " (w" << covdb_get(cpcr, reghdl, NULL, covdbWidth) << ")\n";

            covdbHandle cont, conts = covdb_iterate(cpcr, covdbObjects);
            while((cont = covdb_scan(conts))) {
                const char* contName = covdb_get_str(cont, covdbName);
                const char* autonm = "Automatically";
                bool isAuto2 = covdb_get(cont, reghdl, NULL, covdbAutomatic);
                int wt = covdb_get(cont, reghdl, getTest(), covdbWeight);
                bool isAuto = false;
                if (!strncmp(autonm, contName, sizeof(autonm))) {
                    isAuto = true;
                }
                if (isAuto != isAuto2) {
                    std::cout << "ERROR: isAuto is " << isAuto << " but isAuto2 is " << isAuto2 << "\n";
                }
                std::cout << "  container " << contName << " (weight " << wt << ")\n";

                covdbHandle bin, bins = covdb_iterate(cont, covdbObjects);
                while((bin = covdb_scan(bins))) {
                    showBin(3, bin, reghdl, isAuto, isCross);
                }
                covdb_release_handle(bins);
            }
            covdb_release_handle(conts);
        }
        covdb_release_handle(cpcrs);
    }

public:
    GroupVisCpp(covdbHandle design) : UcapiVisitor(design) {
        _warned = false;
    }
    virtual ~GroupVisCpp() { }

    virtual void startQualifiedInstance(covdbHandle inst, covdbHandle met) {
        if (!isTestbenchMetric(met)) return;
        std::cout << "In instance " << covdb_get_str(inst, covdbFullName) << ": ";
        covdbHandle def = covdb_get_handle(inst, covdbDefinition);

        std::cout << "definition is " << (def ? covdb_get_str(def, covdbName) : "NULL") << "\n";

        covdbHandle par = covdb_get_handle(def, covdbParent);
        if (par) {
            std::cout << " and parent is " << covdb_get_str(par, covdbFullName) << "\n";
        } else {
            warnNoDesign();
        }
    }

    /// This method is called for each covergroup variant (distinct shape
    /// based on parameters).  If the variant has type_option.instance = 1,
    /// its parent will be a covdbSourceInstance.  If the variant does not
    /// have type_option.instance set to 1, the parent will be a 
    /// covdbSourceDefinition (i.e., a module).
    virtual void startVariant(covdbHandle var, covdbHandle met) {
        if (!isTestbenchMetric(met)) return;
        std::cout << "In variant " << covdb_get_str(var, covdbName) << ": ";
        covdbHandle par = covdb_get_handle(var, covdbParent);

        if (par) {
            covdbObjTypesT pty = (covdbObjTypesT)covdb_get(par, NULL, NULL, covdbType);
            std::cout << "parent ";
            if (covdbSourceDefinition == pty) {
                std::cout << "is definition " << covdb_get_str(par, covdbName) << "\n";
            } else {
                std::cout << "is instance " << covdb_get_str(par, covdbFullName);
                covdbHandle mod = covdb_get_handle(par, covdbDefinition);
                std::cout << ", which is an instance of definition " << covdb_get_str(mod, covdbName) << "\n";
            }
        } else {
            warnNoDesign();
        }

        // If you want to dump the bins and contents call this function
        iterateGroupObjects(var);
    }

    virtual void warnNoDesign() {
        if (!_warned) {
            std::cout << "\n\nWarning: the VDB does not contain compilation data. If this database contains only functional coverage data, please recompile using -covg_dump_design\n\n";
            _warned = true;
        }
    }
};

void usage(const char* nm) {
    std::cout << "Usage: " << nm << " vdbdir\n";
    exit(1);
}

int main(int argc, const char* argv[]) {
    if (2 != argc) usage(argv[0]);

    covdbHandle des = covdb_load(covdbDesign, NULL, argv[1]);
    if (!des) {
        std::cout << "Could not open design in directory " << argv[1] << "\n";
        usage(argv[0]);
    }

    covdb_qualified_configure(des, covdbShowGroupsInDesign, "1");

    GroupVisCpp vis(des);
    std::cout << "Starting execution..." << std::endl;
    vis.execute();
    std::cout << "Execution completed." << std::endl;
    covdb_unload(des);
    
    return 0;
}
