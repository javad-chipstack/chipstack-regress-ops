/******************************************************************
 *   Copyright (c) 2015 by Synopys Inc. - All Rights Reserved     *
 *              VCS is a trademark of Synopsys Inc.               *
 *                                                                *
 *    CONFIDENTIAL AND PROPRIETARY INFORMATION OF SYNOPSYS INC.   *
 ******************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include "covdb_user.h"
#include "visit.hh"
#include <map>
#include <string>

class DumpTgl : public UcapiVisitor {
    const char* _modname;
    bool _inmod;
    void indent(int depth) {
        for(int i = 0; i < depth; i++) printf(" ");
    }

    static void errorFilter(covdbHandle errHdl, void* data) {
        char* errstr = covdb_get_str(errHdl, covdbName);
        fprintf(stderr, "Error occurred: %s\n", errstr);
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
        printf("%s\t", pnm);

        const char* onm = covdb_get_str(obj, covdbName);
        printf("(%s)\t", onm);

        int st = covdb_get(obj, region, getTest(), covdbCovStatus);
        if (st & covdbStatusCovered) {
            printf("Covered\n");
        } else if (st & covdbStatusExcluded) {
            printf("Excluded\n");
        } else {
            printf("Uncovered\n");
        }
    }

};


int main(int argc, const char *argv[])
{
    covdbHandle design;
    int i;

    if (argc != 3) {
        printf("Usage: %s vdbdir modname\n", argv[0]);
    }

    const char* dir = argv[1];
    const char* mod = argv[2];

    design = covdb_load(covdbDesign, NULL, dir);
    covdb_qualified_configure(design, covdbExcludeMode, "adaptive");

    if (!design) {
        fprintf(stderr, "Error: you must specify at least one -dir\n");
        exit(1);
    } else {
        DumpTgl vis(design, mod);

        printf("Dumping toggle objects and status for module '%s'\n", mod);
        vis.execute();
        covdb_unload(design);
    }

    return 0;
}

