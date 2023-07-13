#include <stdlib.h>
#include <pd_api.h>

PlaydateAPI *pd;

#include "gifdec_glue.h"

#ifdef TARGET_PLAYDATE

void zhuowei(void) __attribute__((naked));
void zhuowei() {
	__asm__ __volatile__(
		"push {lr}\n"
		"movs.w lr, #0\n"
		"movt lr, #0x805\n"
		"svc #2\n"
		"pop {pc}\n"
	);
}

static void zhuoweiLua(void) {
	zhuowei();

	char *useSystemLua = (char *)0x20011a60;
	*useSystemLua |= 0x1;

	char *useRootPath = (char *)0x20011a88;
	*useRootPath |= 0x1;
}

static int unlockFS(lua_State *L) {
	char *cwd = (char *)0x20040840;
	*cwd = '/';
	
	return 0;
}

static int lockFS(lua_State *L) {
	char *cwd = (char *)0x20040840;
	*cwd = '\0';
	
	return 0;
}

#endif

static const lua_reg giflib[] = {
	{"open", giflib_newobject},
	{"getFrame", giflib_getFrame},
	{"rewind", giflib_rewind},
	{"close", giflib_close},
	{NULL, NULL}
};

#ifdef _WINDLL
__declspec(dllexport)
#endif
int eventHandler(PlaydateAPI* playdate, PDSystemEvent event, uint32_t arg) {
	(void)arg;
	if (event == kEventInit) {
		pd = playdate;
		
		#ifdef TARGET_PLAYDATE
		zhuoweiLua();
		#endif
	}
	else if (event == kEventInitLua) {
		#ifdef TARGET_PLAYDATE
		zhuowei();
		
		pd->lua->addFunction(unlockFS, "scrapbook.fs.unlock", NULL);
		pd->lua->addFunction(lockFS, "scrapbook.fs.lock", NULL);
		#endif
		
		pd->lua->registerClass("scrapbook.gif", giflib, NULL, 0, NULL);
	}
	
	return 0;
}