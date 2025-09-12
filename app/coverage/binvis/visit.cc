/******************************************************************
 *   Copyright (c) 2016 by Synopys Inc. - All Rights Reserved     *
 *              VCS is a trademark of Synopsys Inc.               *
 *                                                                *
 *    CONFIDENTIAL AND PROPRIETARY INFORMATION OF SYNOPSYS INC.   *
 ******************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include "covdb_user.h"
#include "visit.hh"

UcapiVisitor::UcapiVisitor(covdbHandle design)
        : _design(design)
{
    covdbHandle tns, tn;
    /* load and merge all tests found in the design */
    tns = covdb_iterate(_design, covdbAvailableTests);
    tn = covdb_scan(tns);
    visitTestName(tn);
    _test = covdb_load(covdbTest, _design, covdb_get_str(tn, covdbName));
    while((tn = covdb_scan(tns))) {
        visitTestName(tn);
        _test = covdb_loadmerge(covdbTest, _test,
                               covdb_get_str(tn, covdbName));
    }
    covdb_release_handle(tns);

}

UcapiVisitor::UcapiVisitor(covdbHandle design, covdbHandle test)
        : _design(design), _test(test)
{
}


void UcapiVisitor::execute(covdbErrorCB cbf) 
{
    covdbHandle met, mets;
    covdbHandle tbMet = NULL, astMet = NULL;
    covdbHandle inst, insts;
    covdbHandle def, defs;

    covdb_configure(covdbDisplayErrors, (char*)"false");

    /* register error callback function */
    if (cbf)
        // Use function passed to execute
        covdb_set_error_callback(cbf, NULL);
    else if (_errorCallback) 
        // Use function specified at constructor time
        covdb_set_error_callback(_errorCallback, NULL);
    else
        // Use default
        covdb_set_error_callback(errorCB, NULL);

    /* iterate through all top instances in the design */
    insts = covdb_iterate(_design, covdbInstances);
    while((inst = covdb_scan(insts))) {
        recurseIntoObjectsInUnqualifiedInst(inst);
    }
    covdb_release_handle(insts);

    /* iterate through all definitions in the design */
    defs = covdb_iterate(_design, covdbDefinitions);
    while((def = covdb_scan(defs))) {
        recurseIntoObjectsInUnqualifiedDef(def);
    }
    covdb_release_handle(defs);

    /* Find the group and assertion metrics if they are present in _test */
    mets = covdb_iterate(_test, covdbMetrics);
    while((met = covdb_scan(mets))) {
        if (isTestbenchMetric(met)) {
            tbMet = covdb_make_persistent_handle(met);
        } else if (isAssertMetric(met)) {
            astMet = covdb_make_persistent_handle(met);
        }
    }

    /* iterate through assertions from the test handle.  We could do this
     * from the instances or modules, but then we'd miss assertions in the
     * root scope
     */
    if (astMet) {
        covdbHandle ast, asts =
                covdb_qualified_iterate(_test, astMet, covdbObjects);
        while((ast = covdb_scan(asts))) {
            covdbHandle parent = covdb_get_handle(ast, covdbParent);
            covdbHandle blk, blks = covdb_iterate(ast, covdbObjects);
            while((blk = covdb_scan(blks))) {
                const char* blkname = covdb_get_str(blk, covdbName);
                /* find the block name corresponding to covered/success */
                if (!strcmp(blkname, "realsuccesses") ||
                    !strcmp(blkname, "allsuccesses"))
                {
                    visitCovObject(blk, parent, astMet, ast);
                    break;
                }
            }
            covdb_release_handle(blks);
        }
        covdb_release_handle(asts);
    }

    /* iterate through covergroups */
    if (tbMet) {
        covdbHandle grp, grps;
        grps = covdb_qualified_iterate(_test, tbMet, covdbDefinitions);
        while((grp = covdb_scan(grps))) {
            grp = covdb_make_persistent_handle(grp);

            /* Iterate through grp's variants */
            covdbHandle var, vars =
                    covdb_qualified_iterate(grp, tbMet, covdbDefinitions);
            while((var = covdb_scan(vars))) {
                var = covdb_make_persistent_handle(var);

                /* recurse into covergroup contents */
                recurseIntoObjectsInQualifiedRegion(var, tbMet,
                                                    covdbSourceDefinition);

                /* recurse into instances of this variant */
                covdbHandle inst, insts = covdb_iterate(var, covdbInstances);
                while((inst = covdb_scan(insts))) {
                    inst = covdb_make_persistent_handle(inst);
                    recurseIntoObjectsInQualifiedRegion(inst, tbMet, 
                                                        covdbSourceInstance);
                    covdb_release_handle(inst);
                }
                covdb_release_handle(var);
            }
            covdb_release_handle(grp);
        }
        covdb_release_handle(tbMet);
        covdb_release_handle(grps);
    }
}

/*
 * If obj is a coverable object, assign it a code number.  If it's 
 * a container, recurse into its list of contained objects.
 */
void UcapiVisitor::recurseIntoObjects(covdbHandle obj, covdbHandle qinst,
                                      covdbHandle met, covdbHandle parent)
{
    covdbObjTypesT ty = (covdbObjTypesT)covdb_get(obj, qinst, NULL, covdbType);

    switch(ty) {
        case covdbBlock:
        case covdbSequence:
        case covdbCross:
        case covdbIntegerValue:
        case covdbScalarValue:
        case covdbValueSet:
            visitLeafObject(obj, qinst, met, parent);
            if (!isLineMetric(met)) {
                visitCovObject(obj, qinst, met, parent);
            }
            break;

        case covdbContainer:
            {
                obj = covdb_make_persistent_handle(obj);

                startContainer(obj, qinst, met, parent);

                covdbHandle kids, kid;
                kids = covdb_iterate(obj, covdbObjects);
                kid = covdb_scan(kids);

                if (isAssertMetric(met)) {
                    // These are visited from the test handle
                } else {
                    // Recurse into kids
                    if (kid && isLineMetric(met)) {
                        covdbObjTypesT kty = (covdbObjTypesT)
                                covdb_get(kid, qinst, NULL, covdbType);
                        if (covdbBlock == kty) {
                            visitCovObject(obj, qinst, met, parent);
                        }
                    }

                    while(kid) {
                        recurseIntoObjects(kid, qinst, met, obj);
                        kid = covdb_scan(kids);
                    }
                }
                finishContainer(obj, qinst, met, parent);
                covdb_release_handle(kids);
                covdb_release_handle(obj);
            }
            break;

        default:
            printf("Error: unrecognized object type %d\n", ty);
            break;
    }
}

void UcapiVisitor::recurseIntoObjectsInQualifiedRegion(covdbHandle qreg,
                                                       covdbHandle met,
                                                       covdbObjTypesT ty)
{
    covdbHandle objs, obj;

    objs = covdb_iterate(qreg, covdbObjects);
    if (covdbSourceDefinition == ty) {
        startVariant(qreg, met);
    } else if (covdbSourceInstance == ty) {
        startQualifiedInstance(qreg, met);
    }
    while((obj = covdb_scan(objs))) {
        recurseIntoObjects(obj, qreg, met, NULL);
    }
    covdb_release_handle(objs);
    if (covdbSourceDefinition == ty) {
        finishVariant(qreg, met);
    } else if (covdbSourceInstance == ty) {
        finishQualifiedInstance(qreg, met);
    }
}

void UcapiVisitor::recurseIntoObjectsInUnqualifiedDef(covdbHandle reg)
{
    covdbHandle objs, obj;
    covdbHandle met, mets;

    reg = covdb_make_persistent_handle(reg);

    startDefinition(reg);

    /* visit the objects for each metric */
    mets = covdb_iterate(_test, covdbMetrics);
    while((met = covdb_scan(mets))) {
        if (isPathMetric(met)) continue; // path coverage is deprecated
        if (isTestbenchMetric(met) || isAssertMetric(met)) {
            // these test-qualified metrics are accessed through the
            // test handle
            continue;
        }
        covdbHandle var, vars;
        met = covdb_make_persistent_handle(met);
        vars = covdb_qualified_iterate(reg, met, covdbDefinitions);
        while((var = covdb_scan(vars))) {
            recurseIntoObjectsInQualifiedRegion(var, met,
                                                covdbSourceDefinition);
        }
        covdb_release_handle(vars);
        covdb_release_handle(met);
    }
    covdb_release_handle(mets);

    finishDefinition(reg);
}

void UcapiVisitor::recurseIntoObjectsInUnqualifiedInst(covdbHandle reg)
{
    covdbHandle objs, obj;
    covdbHandle met, mets;
    covdbHandle kid, kids;

    reg = covdb_make_persistent_handle(reg);

    startInstance(reg);

    /* descend into children of this instance */
    kids = covdb_iterate(reg, covdbInstances);
    while((kid = covdb_scan(kids))) {
        recurseIntoObjectsInUnqualifiedInst(kid);
    }

    /* visit the objects for each metric */
    mets = covdb_iterate(_test, covdbMetrics);
    while((met = covdb_scan(mets))) {
        if (isPathMetric(met)) continue; // path coverage is deprecated
        if (isTestbenchMetric(met) || isAssertMetric(met)) {
            // these test-qualified metrics are accessed through the
            // test handle
            continue;
        }

        covdbHandle qreg;
        met = covdb_make_persistent_handle(met);
        qreg = covdb_get_qualified_handle(reg, met, covdbIdentity);

        recurseIntoObjectsInQualifiedRegion(qreg, met, covdbSourceInstance);

        covdb_release_handle(qreg);
        covdb_release_handle(met);
    }
    covdb_release_handle(mets);

    finishInstance(reg);
    covdb_release_handle(reg);
}

covdbErrorCB UcapiVisitor::_errorCallback = NULL;

/*
 * callback function we register with UCAPI for errors
 */
void UcapiVisitor::errorCB(covdbHandle errHdl, void *data)
{
    int errcode = covdb_get(errHdl, NULL, NULL, covdbValue);
    if (covdbInvalidPropertyError == errcode ||
        covdbNotImplementedError == errcode ||
        covdbInvalidRelationError == errcode)
    {
        /* There are some unimplemented properties that return errors,
           such as covdbLineNo on condition coverage, which we ignore */
        ;
    } else {
        if (_errorCallback) {
            (_errorCallback)(errHdl, data);
        } else {
            fprintf(stderr, "Error occurred: %s\n",
                    covdb_get_str(errHdl, covdbName));
            exit(1);
        }
    }
}

const char* UcapiVisitor::ucapiObjTypeName(covdbHandle obj, covdbHandle reg) 
{
    const char* res = NULL;
    if (!obj || !reg) return "Null handle";

    covdbObjTypesT ty = (covdbObjTypesT)covdb_get(obj, reg, NULL, covdbType);
    switch(ty) {
    case covdbNullHandle: res = "covdbNullHandle"; break;
    case covdbInternal: res = "covdbInternal"; break;
    case covdbDesign: res = "covdbDesign"; break;
    case covdbIterator: res = "covdbIterator"; break;
    case covdbContainer: res = "covdbContainer"; break;
    case covdbMetric: res = "covdbMetric"; break;
    case covdbSourceInstance: res = "covdbSourceInstance"; break;
    case covdbSourceDefinition: res = "covdbSourceDefinition"; break;
    case covdbBlock: res = "covdbBlock"; break;
    case covdbIntegerValue: res = "covdbIntegerValue"; break;
    case covdbScalarValue: res = "covdbScalarValue"; break;
    case covdbVectorValue: res = "covdbVectorValue"; break;
    case covdbIntervalValue: res = "covdbIntervalValue"; break;
    case covdbBDDValue: res = "covdbBDDValue"; break;
    case covdbCross: res = "covdbCross"; break;
    case covdbSequence: res = "covdbSequence"; break;
    case covdbAnnotation: res = "covdbAnnotation"; break;
    case covdbTest: res = "covdbTest"; break;
    case covdbTestName: res = "covdbTestName"; break;
    case covdbInterval: res = "covdbInterval"; break;
    case covdbExcludeFile: res = "covdbExcludeFile"; break;
    case covdbHierFile: res = "covdbHierFile"; break;
    case covdbEditFile: res = "covdbEditFile"; break;
    case covdbBDD: res = "covdbBDD"; break;
    case covdbError: res = "covdbError"; break;
    case covdbTable: res = "covdbTable"; break;
    case covdbValueSet: res = "covdbValueSet"; break;
    case covdbSBNRange: res = "covdbSBNRange"; break;
    case covdbTestInfo: res = "covdbTestInfo"; break;
    default: res = "unknown?"; break;
    }
    return res;
}
