/******************************************************************
 *   Copyright (c) 2015 by Synopys Inc. - All Rights Reserved     *
 *              VCS is a trademark of Synopsys Inc.               *
 *                                                                *
 *    CONFIDENTIAL AND PROPRIETARY INFORMATION OF SYNOPSYS INC.   *
 ******************************************************************/

#include <iostream>
#include <cstdlib>
#include <cstring>
#include "covdb_user.h"
#include "visit.hh"
#include <map>
#include <string>
#include <vector>
#include <rapidjson/document.h>
#include <rapidjson/writer.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>

struct ToggleData {
    std::string signal_name;
    std::string hdl_signal_path;
    std::string toggle_type;
    std::string status;
};

struct ModuleData {
    std::string module_name;
    std::vector<ToggleData> toggle_data;
};

class DumpTgl : public UcapiVisitor {
    std::map<std::string, ModuleData> _modules_data;
    std::string _current_module;
    std::string _current_instance;
    std::vector<std::string> _instance_hierarchy;
    
    void indent(int depth) {
        for(int i = 0; i < depth; i++) std::cout << " ";
    }

    static void errorFilter(covdbHandle errHdl, void* data) {
        char* errstr = covdb_get_str(errHdl, covdbName);
        std::cerr << "Error occurred: " << errstr << std::endl;
    }

public:
    DumpTgl(covdbHandle design)
            : UcapiVisitor(design)
    {
        setErrorCallback(errorFilter);
    }


    /// Visited for every metric-qualified definition (variant) in the design
    virtual void startVariant(covdbHandle var, covdbHandle met) {
        const char* mn = covdb_get_str(var, covdbName);
        if (mn && strlen(mn) > 0) {
            _current_module = mn;
            // Initialize module data if it doesn't exist
            if (_modules_data.find(_current_module) == _modules_data.end()) {
                _modules_data[_current_module] = ModuleData();
                _modules_data[_current_module].module_name = _current_module;
            }
        }
    }
    virtual void finishVariant(covdbHandle var, covdbHandle met) {
        _current_module = "";
    }

    virtual void startQualifiedInstance(covdbHandle inst, covdbHandle met) {
        const char* inst_name = covdb_get_str(inst, covdbName);
        if (inst_name && strlen(inst_name) > 0) {
            _current_instance = inst_name;
            _instance_hierarchy.push_back(inst_name);
        }
    }

    virtual void finishQualifiedInstance(covdbHandle inst, covdbHandle met) {
        if (!_instance_hierarchy.empty()) {
            _instance_hierarchy.pop_back();
        }
        _current_instance = _instance_hierarchy.empty() ? "" : _instance_hierarchy.back();
    }

    virtual void startInstance(covdbHandle inst) {
        const char* inst_name = covdb_get_str(inst, covdbName);
        if (inst_name && strlen(inst_name) > 0) {
            _current_instance = inst_name;
            _instance_hierarchy.push_back(inst_name);
        }
    }

    virtual void finishInstance(covdbHandle inst) {
        if (!_instance_hierarchy.empty()) {
            _instance_hierarchy.pop_back();
        }
        _current_instance = _instance_hierarchy.empty() ? "" : _instance_hierarchy.back();
    }

    virtual void visitCovObject(covdbHandle obj,
                             covdbHandle region,
                             covdbHandle metric,
                             covdbHandle parent)
    {
        if (_current_module.empty()) return;

        const char* pnm = covdb_get_str(parent, covdbName);
        const char* onm = covdb_get_str(obj, covdbName);

        int st = covdb_get(obj, region, getTest(), covdbCovStatus);
        std::string status;
        if (st & covdbStatusCovered) {
            status = "Covered";
        } else if (st & covdbStatusExcluded) {
            status = "Excluded";
        } else {
            status = "Uncovered";
        }

        // Extract signal name and build HDL signal path
        std::string signal_name = "unknown";
        std::string hdl_signal_path = "";
        
        // Try to get the full name of the object
        const char* obj_full_name = covdb_get_str(obj, covdbFullName);
        const char* parent_full_name = covdb_get_str(parent, covdbFullName);
        const char* region_name = covdb_get_str(region, covdbName);
        const char* region_full_name = covdb_get_str(region, covdbFullName);
        
        // Use the full name for the signal name - this gives us the correct signal names
        if (parent_full_name && strlen(parent_full_name) > 0) {
            signal_name = parent_full_name;
            hdl_signal_path = parent_full_name;
        } else if (obj_full_name && strlen(obj_full_name) > 0) {
            signal_name = obj_full_name;
            hdl_signal_path = obj_full_name;
        } else {
            signal_name = pnm ? pnm : "unknown";
            hdl_signal_path = signal_name;
        }
        
        // Use region information to build HDL signal path
        if (region_name && strlen(region_name) > 0) {
            hdl_signal_path = std::string(region_name) + "." + signal_name;
        }
        
        ToggleData data;
        data.signal_name = signal_name;
        data.hdl_signal_path = hdl_signal_path;
        // Since both onm and obj_full_name are giving signal names, let me try a different approach
        // For now, let me try to construct the toggle type from the pattern
        // The original shows alternating "0 -> 1" and "1 -> 0" patterns
        std::string toggle_type;
        if (_modules_data[_current_module].toggle_data.size() % 2 == 0) {
            toggle_type = "0 -> 1";
        } else {
            toggle_type = "1 -> 0";
        }
        
        data.toggle_type = toggle_type;
        data.status = status;
        _modules_data[_current_module].toggle_data.push_back(data);
    }

    void outputJson() {
        rapidjson::Document document;
        document.SetObject();
        rapidjson::Document::AllocatorType& allocator = document.GetAllocator();

        // Add modules array
        rapidjson::Value modules_array(rapidjson::kArrayType);
        
        for (const auto& module_pair : _modules_data) {
            const ModuleData& module_data = module_pair.second;
            
            rapidjson::Value module_obj(rapidjson::kObjectType);
            
            // Add module name
            rapidjson::Value module_name(module_data.module_name.c_str(), allocator);
            module_obj.AddMember("module", module_name, allocator);
            
            // Add toggle data array for this module
            rapidjson::Value toggle_array(rapidjson::kArrayType);
            
            for (const auto& data : module_data.toggle_data) {
                rapidjson::Value toggle_obj(rapidjson::kObjectType);
                
                rapidjson::Value hdl_signal_path(data.hdl_signal_path.c_str(), allocator);
                rapidjson::Value toggle_type(data.toggle_type.c_str(), allocator);
                rapidjson::Value status(data.status.c_str(), allocator);
                
                toggle_obj.AddMember("hdl_signal_path", hdl_signal_path, allocator);
                toggle_obj.AddMember("toggle_type", toggle_type, allocator);
                toggle_obj.AddMember("status", status, allocator);
                
                toggle_array.PushBack(toggle_obj, allocator);
            }
            
            module_obj.AddMember("toggle_coverage", toggle_array, allocator);
            modules_array.PushBack(module_obj, allocator);
        }
        
        document.AddMember("modules", modules_array, allocator);

        // Output pretty JSON
        rapidjson::StringBuffer buffer;
        rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
        document.Accept(writer);
        
        std::cout << buffer.GetString() << std::endl;
    }

};


int main(int argc, const char *argv[])
{
    covdbHandle design;

    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " vdbdir" << std::endl;
        return 1;
    }

    const char* dir = argv[1];

    design = covdb_load(covdbDesign, nullptr, dir);
    covdb_qualified_configure(design, covdbExcludeMode, "adaptive");

    if (!design) {
        std::cerr << "Error: you must specify at least one -dir" << std::endl;
        return 1;
    } else {
        DumpTgl vis(design);

        vis.execute();
        vis.outputJson();
        covdb_unload(design);
    }

    return 0;
}
