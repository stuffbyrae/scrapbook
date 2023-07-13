#ifndef GIFDEC_GLUE_H
#define GIFDEC_GLUE_H

#include <stdlib.h>

#include "gifdec.h"

extern PlaydateAPI *pd;

static uint8_t round_color(int r, int g, int b) {
	if((r + g + b) / 3 >= 0x80) return kColorWhite;
	else return kColorBlack;
}

static int pdgd_get_frame(gd_GIF *gif, LCDBitmap *bmp) {
	int status = gd_get_frame(gif);
	if (status != 1) return status;
	
	uint8_t *canvas = malloc(3 * gif->width * gif->height);
	gd_render_frame(gif, canvas);
	
	int w, h, stride;
	int off = 0;
	
	uint8_t *data;
	uint8_t *mask;
	pd->graphics->getBitmapData(bmp, &w, &h, &stride, &mask, &data);
	
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < stride; x++) {
			for (int bit = 0; bit < 8; bit++) {
				if (8 * x + bit >= gif->width) break;
				
				data[y * stride + x] <<= 1;
				
				uint8_t r = canvas[off];
				uint8_t g = canvas[off + 1];
				uint8_t b = canvas[off + 2];
				
				data[y * stride + x] &= 0xfe;
				data[y * stride + x] |= round_color(r, g, b);
				
				off += 3;
			}
		}
	}
	free(canvas);
	
	return 1;
}

static int giflib_newobject(lua_State *L) {
	SDFile **fd;
	
	void *ret = pd->lua->getArgObject(1, "playdate.file.file", (LuaUDObject **)&fd);
	if (ret == NULL) {
		pd->system->error("argument #1 to scrapbook.gif.open must be an open file");
		return 0;
	}
	
	gd_GIF *gif = gd_open_gif(*fd);
	
	if(gif == NULL) {
		pd->lua->pushNil();
		return 1;
	}
	
	LuaUDObject *ud = pd->lua->pushObject(gif, "scrapbook.gif", 0);
	pd->lua->retainObject(ud);
	
	return 1;
}

static int giflib_getFrame(lua_State *L) {
	gd_GIF *gif = pd->lua->getArgObject(1, "scrapbook.gif", NULL);
	
	if (gif == NULL) {
		pd->system->error("argument #1 to scrapbook.gif:getFrame must be a scrapbook.gif object");
		return 0;
	}
	
	LCDBitmap *bmp;
	
	if (pd->lua->getArgCount() == 2) {
		bmp = pd->lua->getBitmap(2);
	}
	else {
		bmp = pd->graphics->newBitmap(gif->width, gif->height, kColorBlack);
	}
	
	int status = pdgd_get_frame(gif, bmp);
	if (status == 1) {
		pd->lua->pushBitmap(bmp);
		return 1;
	}
	else if (!status) {
		if (pd->lua->getArgCount() < 2) {
			pd->graphics->freeBitmap(bmp);
		}
		
		pd->lua->pushNil();
		pd->lua->pushString("no more frames in GIF");
	}
	else {
		if (pd->lua->getArgCount() < 2) {
			pd->graphics->freeBitmap(bmp);
		}
		
		pd->lua->pushNil();
		pd->lua->pushString("error in GIF decoding");
	}
	
	return 2;
}

static int giflib_rewind(lua_State *L) {
	gd_GIF *gif = pd->lua->getArgObject(1, "scrapbook.gif", NULL);
	
	if (gif == NULL) {
		pd->system->error("argument #1 to scrapbook.gif:rewind must be a scrapbook.gif object");
		return 0;
	}
	
	gd_rewind(gif);
	
	return 0;
}

static int giflib_close(lua_State *L) {
	LuaUDObject *ud;
	gd_GIF *gif = pd->lua->getArgObject(1, "scrapbook.gif", &ud);
	
	if (gif == NULL) {
		pd->system->error("argument #1 to scrapbook.gif:close must be a scrapbook.gif object");
		return 0;
	}
	
	gd_close_gif(gif);
	pd->lua->releaseObject(ud);
	
	return 0;
}

#endif