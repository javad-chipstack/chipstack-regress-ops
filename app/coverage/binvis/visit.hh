/******************************************************************
 *   Copyright (c) 2015 by Synopys Inc. - All Rights Reserved     *
 *              VCS is a trademark of Synopsys Inc.               *
 *                                                                *
 *    CONFIDENTIAL AND PROPRIETARY INFORMATION OF SYNOPSYS INC.   *
 ******************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include "covdb_user.h"

/// Generic visitor class for a UCAPI coverage database.
/// Override the visitors you wish to use.  There are metric-specific
/// visitors (e.g., for toggle) and generic visitors that will visit
/// all regions, containers and/or leaf objects in the coverage model.
class UcapiVisitor {
    covdbHandle _design;
    covdbHandle _test;
    static covdbErrorCB _errorCallback;

    void recurseIntoObjects(covdbHandle obj, covdbHandle qinst,
                            covdbHandle met, covdbHandle parent);
    void recurseIntoObjectsInUnqualifiedInst(covdbHandle inst);
    void recurseIntoObjectsInUnqualifiedDef(covdbHandle def);
    void recurseIntoObjectsInQualifiedRegion(covdbHandle region,
                                             covdbHandle met,
                                             covdbObjTypesT ty);

public:
    /// Constructor that takes an already-loaded design handle.
    /// Will automatically load/merge all available tests from the design.
    UcapiVisitor(covdbHandle design);

    /// Constructor that takes already-loaded design and test handles.
    UcapiVisitor(covdbHandle design, covdbHandle test);

    /// If an error is detected, and this is set, it will be called
    /// after UcapiVisitor filters known ignore-able errors
    void setErrorCallback(covdbErrorCB errfn) {
        _errorCallback = errfn;
    }

    covdbHandle getDesign() { return _design; }
    covdbHandle getTest() { return _test; }

    /// Visited for every unqualified instance in the design
    /// After startInstance(I) is called, start and finish will be called
    /// for every descendent of I before finishInstance(I) is called
    virtual void startInstance(covdbHandle inst) { }
    virtual void finishInstance(covdbHandle inst) { }

    /// Visited for every metric-qualified instance in the design.  
    /// For a given qualifed instance Q, startInstance(Q) will be called
    /// only after all descendent instances have been started and finished
    virtual void startQualifiedInstance(covdbHandle inst, covdbHandle met) { }
    virtual void finishQualifiedInstance(covdbHandle inst, covdbHandle met) { }

    /// Visited once for every unqualified definition (module)
    virtual void startDefinition(covdbHandle var) { }
    virtual void finishDefinition(covdbHandle var) { }

    /// Visited for every metric-qualified definition (variant) in the design
    virtual void startVariant(covdbHandle var, covdbHandle met) { }
    virtual void finishVariant(covdbHandle var, covdbHandle met) { }

    /// Each metric is started and finished once for each instance
    virtual void startMetric(covdbHandle met) { }
    virtual void finishMetric(covdbHandle met) { }

    /// Visited once for each testname found in design
    virtual void visitTestName(covdbHandle testNameHdl) { }

    /// Visits each container 
    virtual void startContainer(covdbHandle obj,
                                covdbHandle region,
                                covdbHandle metric,
                                covdbHandle parent) { }
    virtual void finishContainer(covdbHandle obj,
                                 covdbHandle region,
                                 covdbHandle metric,
                                 covdbHandle parent) { }

    /// Visits once for each leaf object in the design across all
    /// metrics. Corresponding start/finish visitors will be called for
    /// containing regions.
    virtual void visitLeafObject(covdbHandle obj,
                                 covdbHandle region,
                                 covdbHandle metric,
                                 covdbHandle parent) { }

    /// Visits once for each coverable object in the design across
    /// all metrics.  This is different from visitLeafObject in that it
    /// may pass a container if that is the metric's lowest-level 
    /// coverable object (e.g., basic blocks for line coverage), whereas
    /// visitLeafObject will never pass a container.
    /// This is the preferred method to use in general.  If you use both
    /// there will be a lot of overlap between the two.
    virtual void visitCovObject(covdbHandle obj,
                                covdbHandle region,
                                covdbHandle metric,
                                covdbHandle parent) { }

    // Call this function to iterate the design
    void execute(covdbErrorCB cbf=NULL);

    // Error handler - will be used by default, or user can invoke
    // after checking for special error conditions in their own 
    // callback first
    static void errorCB(covdbHandle errHdl, void *data);

    static const char* ucapiObjTypeName(covdbHandle obj, covdbHandle reg);
};

