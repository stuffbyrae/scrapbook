#ifndef GIFDEC_H
#define GIFDEC_H

#include <stdint.h>
#include <sys/types.h>
#include <pd_api.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct gd_Palette {
	int size;
	uint8_t colors[0x100 * 3];
} gd_Palette;

typedef struct gd_GCE {
	uint16_t delay;
	uint8_t tindex;
	uint8_t disposal;
	int input;
	int transparency;
} gd_GCE;

typedef struct Entry {
	uint16_t length;
	uint16_t prefix;
	uint8_t  suffix;
} Entry;

typedef struct Table {
	int bulk;
	int nentries;
	Entry *entries;
} Table;

typedef struct gd_GIF {
	SDFile *fd;
	off_t anim_start;
	uint16_t width, height;
	uint16_t depth;
	uint16_t loop_count;
	gd_GCE gce;
	gd_Palette *palette;
	gd_Palette lct, gct;
	void (*plain_text)(
		struct gd_GIF *gif, uint16_t tx, uint16_t ty,
		uint16_t tw, uint16_t th, uint8_t cw, uint8_t ch,
		uint8_t fg, uint8_t bg
	);
	void (*comment)(struct gd_GIF *gif);
	void (*application)(struct gd_GIF *gif, char id[8], char auth[3]);
	uint16_t fx, fy, fw, fh;
	uint8_t bgindex;
	uint8_t *canvas, *frame;
} gd_GIF;

typedef struct Decoder {
	gd_GIF *gif;
	
	uint8_t sub_len, shift, byte;
	int init_key_size, key_size, table_is_full;
	int frm_off, frm_size, str_len;
	uint16_t key, clear, stop;
	int ret;
	Table *table;
	Entry entry;
	off_t start, end;
	
	int interlace;
} Decoder;

gd_GIF *gd_open_gif(SDFile *fd);

int gd_begin_read(gd_GIF *gif, Decoder **decptr);
int gd_step_read(Decoder *dec);
void gd_end_read(Decoder *dec);

int gd_get_frame(gd_GIF *gif);
void gd_render_frame(gd_GIF *gif, uint8_t *buffer);
int gd_is_bgcolor(gd_GIF *gif, uint8_t color[3]);
void gd_rewind(gd_GIF *gif);
void gd_close_gif(gd_GIF *gif);

#ifdef __cplusplus
}
#endif

#endif /* GIFDEC_H */	