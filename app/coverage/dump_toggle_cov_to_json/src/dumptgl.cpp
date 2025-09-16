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

class DumpTgl : public UcapiVisitor {
    const char* _modname;
    bool _inmod;
    void indent(int depth) {
        for(int i = 0; i < depth; i++) std::cout << " ";
    }

    static void errorFilter(covdbHandle errHdl, void* data) {
        char* errstr = covdb_get_str(errHdl, covdbName);
        std::cerr << "Error occurred: " << errstr << std::endl;
    }

public:
    DumpTgl(covdbHandle design, const char* mod)
            : UcapiVisitor(design), _modname(mod), _inmod(false)
    {
        setErrorCallback(errorFilter);
    }


    /// Visited for every metric-qualified definition (variant) in the design
    virtual void startVariant(covdbHandle var, covdbHandle met) {
        const char* mn = covdb_get_str(var, covdbName);
        if (!strcmp(mn, _modname)) {
            _inmod = true;
        }
    }
    virtual void finishVariant(covdbHandle var, covdbHandle met) {
        _inmod = false;
    }

    virtual void visitCovObject(covdbHandle obj,
                             covdbHandle region,
                             covdbHandle metric,
                             covdbHandle parent)
    {
        if (!_inmod) return;

        const char* pnm = covdb_get_str(parent, covdbName);
        std::cout << pnm << "\t";

        const char* onm = covdb_get_str(obj, covdbName);
        std::cout << "(" << onm << ")\t";

        int st = covdb_get(obj, region, getTest(), covdbCovStatus);
        if (st & covdbStatusCovered) {
            std::cout << "Covered" << std::endl;
        } else if (st & covdbStatusExcluded) {
            std::cout << "Excluded" << std::endl;
        } else {
            std::cout << "Uncovered" << std::endl;
        }
    }

};


int main(int argc, const char *argv[])
{
    covdbHandle design;

    if (argc != 3) {
        std::cout << "Usage: " << argv[0] << " vdbdir modname" << std::endl;
        return 1;
    }

    const char* dir = argv[1];
    const char* mod = argv[2];

    design = covdb_load(covdbDesign, nullptr, dir);
    covdb_qualified_configure(design, covdbExcludeMode, "adaptive");

    if (!design) {
        std::cerr << "Error: you must specify at least one -dir" << std::endl;
        return 1;
    } else {
        DumpTgl vis(design, mod);

        std::cout << "Dumping toggle objects and status for module '" << mod << "'" << std::endl;
        vis.execute();
        covdb_unload(design);
    }

    return 0;
}
