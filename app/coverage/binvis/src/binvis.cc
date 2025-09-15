/// This example program iterates through all covergroup definitions
/// and instances and sets every bin as covered.  Instead of using 
/// visitCovObject, it iterates from the regions themselves.

#include "covdb_user.h"
#include "visit.hh"

class groupVis : public UcapiVisitor {
    void indent(int depth) {
        for(int i = 0; i < depth; i++) printf("..");
    }

    void showBin(int depth, covdbHandle bin, covdbHandle reghdl, bool isAuto,
                 bool isCross)
    {
        indent(depth);
        printf("(%s) ", ucapiObjTypeName(bin, reghdl));

        int ed = covdb_get(bin, reghdl, getTest(), covdbCovered);
        int ab = covdb_get(bin, reghdl, getTest(), covdbCoverable);
        int ct = covdb_get(bin, reghdl, getTest(), covdbCovCount);
        printf("%d/%d (count %d)", ed, ab, ct);
        printf(" %s ", covdb_get_str(bin, covdbName));
        if (isAuto) {
            printf("[auto] (%s) ", covdb_get_str(bin, covdbValueName));
        } else {
            printf("[user]");
        }

        covdbObjTypesT ty = (covdbObjTypesT)
                covdb_get(bin, reghdl, NULL, covdbType);
        bool first = true;
        if (covdbBlock == ty) {
            covdbHandle cm, cs = covdb_iterate(bin, covdbObjects);
            while((cm = covdb_scan(cs))) {
                if (first) { printf("\n"); first = false; }
                showBin(depth+1, cm, reghdl, isAuto, isCross);
            }
            covdb_release_handle(cs);
        } else if (covdbCross == ty) {
            if (isCross) {
                covdbHandle cmp, cmps = 
                        covdb_iterate(bin, covdbComponents);
                printf("\n"); indent(depth+1); printf("Components:");
                while((cmp = covdb_scan(cmps))) {
                    if (first) { printf("\n"); first = false; }
                    showBin(depth+2, cmp, reghdl, isAuto, isCross);
                }
                covdb_release_handle(cmps);
                printf("\n"); indent(depth+1); printf("Objects:");
                first = true;
                covdbHandle k, ks = covdb_iterate(bin, covdbObjects);
                while((k = covdb_scan(ks))) {
                    if (first) { printf("\n"); first = false; }
                    showBin(depth+2, k, reghdl, isAuto, isCross);
                }
                if (first) printf("NONE");
                covdb_release_handle(ks);
            }
        } else if (covdbValueSet == ty) {
            covdbHandle kid, kids = covdb_iterate(bin, covdbObjects);
            first = true;
            while((kid = covdb_scan(kids))) {
                if (first) { printf("\n"); first = false; }
                showBin(depth+1, kid, reghdl, isAuto, isCross);
            }
            covdb_release_handle(kids);
        }
        printf("\n");
    }


    /// iterate all coverpoints and crosses (and their bins) from a
    /// testbench-qualified instance or definition handle
    void iterateGroupObjects(covdbHandle reghdl) {
        covdbHandle cpcr, cpcrs = covdb_iterate(reghdl, covdbObjects);
        while((cpcr = covdb_scan(cpcrs))) {
            const char* ann = covdb_get_annotation(cpcr, IS_CROSS);
            bool isCross = (*ann == '1');
            printf(" %s %s (w%d)\n", isCross?"cross":"coverpoint",
                   covdb_get_str(cpcr, covdbName),
                   covdb_get(cpcr, reghdl, NULL, covdbWidth));

            covdbHandle cont, conts = covdb_iterate(cpcr, covdbObjects);
            while((cont = covdb_scan(conts))) {
                const char* contName = covdb_get_str(cont, covdbName);
                const char* autonm = "Automatically";
                bool isAuto2 = covdb_get(cont, reghdl, NULL, covdbAutomatic);
                int wt = covdb_get(cont, reghdl, getTest(), covdbWeight);
                bool isAuto = false;
                if (!strncmp(autonm, contName, sizeof(autonm)))
                {
                    isAuto = true;
                }
                if (isAuto != isAuto2) printf("ERROR: isAuto is %d but isAuto2 is %d\n", isAuto, isAuto2);
                printf("  container %s (weight %d)\n", contName, wt);

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
    groupVis(covdbHandle design) : UcapiVisitor(design) {
        _warned = false;
    }
    virtual ~groupVis() { }

    virtual void startQualifiedInstance(covdbHandle inst, covdbHandle met) {
        if (!isTestbenchMetric(met)) return;
        printf("In instance %s: ", covdb_get_str(inst, covdbFullName));
        covdbHandle def = covdb_get_handle(inst, covdbDefinition);

        printf("definition is %s\n", def ? covdb_get_str(def, covdbName) 
               : "NULL");

        covdbHandle par = covdb_get_handle(def, covdbParent);
        if (par) {
            printf(" and parent is %s\n", covdb_get_str(par, covdbFullName));
        }
        else {
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
        printf("In variant %s: ", covdb_get_str(var, covdbName));
        covdbHandle par = covdb_get_handle(var, covdbParent);

        if (par) {

        covdbObjTypesT pty =
                (covdbObjTypesT)covdb_get(par, NULL, NULL, covdbType);
            printf("parent ");
            if (covdbSourceDefinition == pty) {
                printf("is definition %s\n", covdb_get_str(par, covdbName));
            } else {
                printf("is instance %s", covdb_get_str(par, covdbFullName));
                covdbHandle mod = covdb_get_handle(par, covdbDefinition);
                printf(", which is an instance of definition %s\n",
                       covdb_get_str(mod, covdbName));
            }
        }
        else {
            warnNoDesign();
        }

        // If you want to dump the bins and contents call this function
        iterateGroupObjects(var);
    }

    virtual void warnNoDesign() {
        if (!_warned) {
            printf("\n\nWarning: the VDB does not contain compilation data. If this database contains only functional coverage data, please recompile using -covg_dump_design\n\n");
            _warned = true;
        }
    }
private:
    bool _warned;
};

void usage(const char* nm)
{
    printf("Usage: %s vdbdir\n", nm);
    exit(1);
}

int main(int argc, const char* argv[])
{
    if (2 != argc) usage(argv[0]);

    covdbHandle des = covdb_load(covdbDesign, NULL, argv[1]);
    if (!des) {
        printf("Could not open design in directory %s\n", argv[1]);
        usage(argv[0]);
    }

    covdb_qualified_configure(des, covdbShowGroupsInDesign, "1");

    groupVis vis(des);
    vis.execute();
    covdb_unload(des);
}
