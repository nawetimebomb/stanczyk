#ifndef NLISP_INTRIRNSICS_H
#define NLISP_INTRIRNSICS_H

#define NASSERT(args, cond, error) \
    if (!(cond)) { nexp_delete(args); return nexp_new_error(error); }

#endif
