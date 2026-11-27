#ifndef PERL_IOS_PORT_H
#define PERL_IOS_PORT_H
#include "ios_error.h"
#undef stdin
#undef stdout
#undef stderr
#define stdin thread_stdin
#define stdout thread_stdout
#define stderr thread_stderr
__attribute__((visibility("hidden"))) int ios_perl_isatty(int fd);
__attribute__((visibility("hidden"))) PerlIO *ios_perl_popen(const char *cmd, const char *mode);
#define isatty ios_perl_isatty
/* Preserve argv boundaries when crossing ios_system's command-string API. */
static __inline__ void ios_perl_quote(pTHX_ SV *command, const char *arg) {
    sv_catpvs(command, "'");
    while (*arg) {
        if (*arg == '\'')
            sv_catpvs(command, "'\\''");
        else
            sv_catpvn(command, arg, 1);
        ++arg;
    }
    sv_catpvs(command, "' ");
}
#endif
