#ifndef wtf

#include <stdio.h>
#include <stdlib.h>

#define MAX(a,b) \
	({ __typeof__ (a) _a = (a); \
	   __typeof__ (b) _b = (b); \
	   _a > _b ? _a : _b; })

/* W.arning T.roubleshoot F.unction */
#define wtf(assertion, format, args...)					\
	do {								\
		if (assertion) {					\
			fprintf(stderr, "(%s, %d): " format "\n",	\
					__FILE__, __LINE__,##args);	\
			exit(EXIT_FAILURE);				\
		}							\
	} while(0)

#endif
