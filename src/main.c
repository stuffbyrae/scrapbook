#include <stdlib.h>
#include <pd_api.h>

PlaydateAPI *pd;

#include "gifdec_glue.h"

static const lua_reg giflib[] = {
	{"open", giflib_newobject},
	{"getFrame", giflib_getFrame},
	{"getDecoder", giflib_getDecoder},
	{"rewind", giflib_rewind},
	{"close", giflib_close},
	{NULL, NULL}
};

static const lua_reg gifdec[] = {
	{"step", gifdec_step},
	{NULL, NULL}
};

#ifdef _WINDLL
__declspec(dllexport)
#endif
int eventHandler(PlaydateAPI* playdate, PDSystemEvent event, uint32_t arg) {
	(void)arg;
	if (event == kEventInit) {
		pd = playdate;
	}
	else if (event == kEventInitLua) {
		pd->lua->registerClass("scrapbook.gif", giflib, NULL, 0, NULL);
		pd->lua->registerClass("scrapbook.gifDec", gifdec, NULL, 0, NULL);
	}
	
	return 0;
}