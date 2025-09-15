/// C++ version of binvis - iterates through all covergroup definitions
/// and instances and displays coverage information for every bin.
/// This version generates the same output as the original binvis.

#include "covdb_user.h"
#include "visit.hh"
#include <iostream>
#include <iomanip>
#include <rapidjson/document.h>
#include <rapidjson/writer.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>

using namespace rapidjson;

class GroupVisCpp : public UcapiVisitor {
private:
    bool _warned;
    Document _jsonDoc;
    Value* _currentInstance;
    Value* _currentVariant;
    

    Value showBin(covdbHandle bin, covdbHandle reghdl, bool isAuto, bool isCross) {
        Value binObj(kObjectType);
        
        // Add basic bin information
        const char* typeName = ucapiObjTypeName(bin, reghdl);
        const char* binName = covdb_get_str(bin, covdbName);
        if (!typeName) typeName = "unknown";
        if (!binName) binName = "unknown";
        binObj.AddMember("type", Value(typeName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
        binObj.AddMember("name", Value(binName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
        
        int ed = covdb_get(bin, reghdl, getTest(), covdbCovered);
        int ab = covdb_get(bin, reghdl, getTest(), covdbCoverable);
        int ct = covdb_get(bin, reghdl, getTest(), covdbCovCount);
        
        binObj.AddMember("covered", ed, _jsonDoc.GetAllocator());
        binObj.AddMember("coverable", ab, _jsonDoc.GetAllocator());
        binObj.AddMember("count", ct, _jsonDoc.GetAllocator());
        binObj.AddMember("isAuto", isAuto, _jsonDoc.GetAllocator());
        binObj.AddMember("isCross", isCross, _jsonDoc.GetAllocator());
        
        if (isAuto) {
            const char* valueName = covdb_get_str(bin, covdbValueName);
            if (valueName) {
                binObj.AddMember("valueName", Value(valueName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            }
        }

        covdbObjTypesT ty = (covdbObjTypesT)covdb_get(bin, reghdl, NULL, covdbType);
        
        if (covdbBlock == ty) {
            Value objects(kArrayType);
            covdbHandle cm, cs = covdb_iterate(bin, covdbObjects);
            while((cm = covdb_scan(cs))) {
                objects.PushBack(showBin(cm, reghdl, isAuto, isCross), _jsonDoc.GetAllocator());
            }
            covdb_release_handle(cs);
            binObj.AddMember("objects", objects, _jsonDoc.GetAllocator());
        } else if (covdbCross == ty) {
            Value components(kArrayType);
            covdbHandle cmp, cmps = covdb_iterate(bin, covdbComponents);
            while((cmp = covdb_scan(cmps))) {
                components.PushBack(showBin(cmp, reghdl, isAuto, isCross), _jsonDoc.GetAllocator());
            }
            covdb_release_handle(cmps);
            binObj.AddMember("components", components, _jsonDoc.GetAllocator());
            
            Value objects(kArrayType);
            covdbHandle k, ks = covdb_iterate(bin, covdbObjects);
            while((k = covdb_scan(ks))) {
                objects.PushBack(showBin(k, reghdl, isAuto, isCross), _jsonDoc.GetAllocator());
            }
            covdb_release_handle(ks);
            binObj.AddMember("objects", objects, _jsonDoc.GetAllocator());
        } else if (covdbValueSet == ty) {
            Value objects(kArrayType);
            covdbHandle kid, kids = covdb_iterate(bin, covdbObjects);
            while((kid = covdb_scan(kids))) {
                objects.PushBack(showBin(kid, reghdl, isAuto, isCross), _jsonDoc.GetAllocator());
            }
            covdb_release_handle(kids);
            binObj.AddMember("objects", objects, _jsonDoc.GetAllocator());
        }
        // For leaf node types (interval, integer, scalar, vector, BDD), no additional processing needed
        
        return binObj;
    }

    /// iterate all coverpoints and crosses (and their bins) from a
    /// testbench-qualified instance or definition handle
    Value iterateGroupObjects(covdbHandle reghdl) {
        Value coverpoints(kArrayType);
        covdbHandle cpcr, cpcrs = covdb_iterate(reghdl, covdbObjects);
        while((cpcr = covdb_scan(cpcrs))) {
            const char* ann = covdb_get_annotation(cpcr, IS_CROSS);
            bool isCross = (*ann == '1');
            
            Value coverpoint(kObjectType);
            const char* cpName = covdb_get_str(cpcr, covdbName);
            coverpoint.AddMember("type", Value(isCross ? "cross" : "coverpoint", _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            coverpoint.AddMember("name", Value(cpName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            coverpoint.AddMember("width", covdb_get(cpcr, reghdl, NULL, covdbWidth), _jsonDoc.GetAllocator());

            Value containers(kArrayType);
            covdbHandle cont, conts = covdb_iterate(cpcr, covdbObjects);
            if (conts) {
                while((cont = covdb_scan(conts))) {
                    const char* contName = covdb_get_str(cont, covdbName);
                    if (!contName) contName = "unknown";
                    
                    const char* autonm = "Automatically";
                    bool isAuto2 = covdb_get(cont, reghdl, NULL, covdbAutomatic);
                    int wt = covdb_get(cont, reghdl, getTest(), covdbWeight);
                    bool isAuto = false;
                    if (contName && !strncmp(autonm, contName, sizeof(autonm))) {
                        isAuto = true;
                    }
                    
                    Value container(kObjectType);
                    container.AddMember("name", Value(contName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
                    container.AddMember("weight", wt, _jsonDoc.GetAllocator());
                    container.AddMember("isAuto", isAuto, _jsonDoc.GetAllocator());

                    Value bins(kArrayType);
                    covdbHandle bin, bins_iter = covdb_iterate(cont, covdbObjects);
                    if (bins_iter) {
                        while((bin = covdb_scan(bins_iter))) {
                            bins.PushBack(showBin(bin, reghdl, isAuto, isCross), _jsonDoc.GetAllocator());
                        }
                        covdb_release_handle(bins_iter);
                    }
                    container.AddMember("bins", bins, _jsonDoc.GetAllocator());
                    containers.PushBack(container, _jsonDoc.GetAllocator());
                }
                covdb_release_handle(conts);
            }
            coverpoint.AddMember("containers", containers, _jsonDoc.GetAllocator());
            coverpoints.PushBack(coverpoint, _jsonDoc.GetAllocator());
        }
        covdb_release_handle(cpcrs);
        return coverpoints;
    }

public:
    GroupVisCpp(covdbHandle design) : UcapiVisitor(design) {
        _warned = false;
        _jsonDoc.SetObject();
        _jsonDoc.AddMember("coverageData", Value("binvis_output", _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
        _jsonDoc.AddMember("instances", Value(kArrayType), _jsonDoc.GetAllocator());
        _currentInstance = nullptr;
        _currentVariant = nullptr;
    }
    virtual ~GroupVisCpp() { }

    virtual void startQualifiedInstance(covdbHandle inst, covdbHandle met) {
        if (!isTestbenchMetric(met)) return;
        
        Value& instances = _jsonDoc["instances"];
        Value instance(kObjectType);
        
        const char* instName = covdb_get_str(inst, covdbFullName);
        instance.AddMember("name", Value(instName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
        
        covdbHandle def = covdb_get_handle(inst, covdbDefinition);
        const char* defName = def ? covdb_get_str(def, covdbName) : "NULL";
        instance.AddMember("definition", Value(defName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
        
        covdbHandle par = covdb_get_handle(def, covdbParent);
        if (par) {
            const char* parName = covdb_get_str(par, covdbFullName);
            instance.AddMember("parent", Value(parName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
        } else {
            warnNoDesign();
        }
        
        instance.AddMember("variants", Value(kArrayType), _jsonDoc.GetAllocator());
        instances.PushBack(instance, _jsonDoc.GetAllocator());
    }

    /// This method is called for each covergroup variant (distinct shape
    /// based on parameters).  If the variant has type_option.instance = 1,
    /// its parent will be a covdbSourceInstance.  If the variant does not
    /// have type_option.instance set to 1, the parent will be a 
    /// covdbSourceDefinition (i.e., a module).
    virtual void startVariant(covdbHandle var, covdbHandle met) {
        if (!isTestbenchMetric(met)) return;
        
        Value& instances = _jsonDoc["instances"];
        
        // If no instances exist, create a default one for the module
        if (instances.Size() == 0) {
            Value instance(kObjectType);
            instance.AddMember("name", Value("covergroup_showcase", _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            instance.AddMember("definition", Value("covergroup_showcase", _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            instance.AddMember("parent", Value("", _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            instance.AddMember("variants", Value(kArrayType), _jsonDoc.GetAllocator());
            instances.PushBack(instance, _jsonDoc.GetAllocator());
        }
        
        Value& currentInstance = instances[instances.Size() - 1];
        Value& variants = currentInstance["variants"];
        
        Value variant(kObjectType);
        const char* varName = covdb_get_str(var, covdbName);
        variant.AddMember("name", Value(varName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
        
        covdbHandle par = covdb_get_handle(var, covdbParent);
        if (par) {
            covdbObjTypesT pty = (covdbObjTypesT)covdb_get(par, NULL, NULL, covdbType);
            if (covdbSourceDefinition == pty) {
                variant.AddMember("parentType", Value("definition", _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
                const char* parName = covdb_get_str(par, covdbName);
                variant.AddMember("parentName", Value(parName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            } else {
                variant.AddMember("parentType", Value("instance", _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
                const char* parName = covdb_get_str(par, covdbFullName);
                variant.AddMember("parentName", Value(parName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
                covdbHandle mod = covdb_get_handle(par, covdbDefinition);
                const char* modName = covdb_get_str(mod, covdbName);
                variant.AddMember("parentDefinition", Value(modName, _jsonDoc.GetAllocator()), _jsonDoc.GetAllocator());
            }
        } else {
            warnNoDesign();
        }

        // Get the coverpoints and crosses for this variant
        variant.AddMember("coverpoints", iterateGroupObjects(var), _jsonDoc.GetAllocator());
        variants.PushBack(variant, _jsonDoc.GetAllocator());
    }

    virtual void warnNoDesign() {
        if (!_warned) {
            std::cout << "\n\nWarning: the VDB does not contain compilation data. If this database contains only functional coverage data, please recompile using -covg_dump_design\n\n";
            _warned = true;
        }
    }
    
    void outputJSON() {
        StringBuffer buffer;
        PrettyWriter<StringBuffer> writer(buffer);
        _jsonDoc.Accept(writer);
        std::cout << buffer.GetString() << std::endl;
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
    vis.execute();
    vis.outputJSON();
    covdb_unload(des);
    
    return 0;
}
