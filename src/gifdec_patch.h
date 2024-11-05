#ifndef GIFDEC_PATCH_H
#define GIFDEC_PATCH_H

#include <pd_api.h>

extern PlaydateAPI *pd;

static off_t pd_lseek(SDFile *fd, off_t offset, int whence) {
	pd->file->seek(fd, (int)offset, whence);
	return pd->file->tell(fd);
}

#define read(fd, buf, len) (ssize_t)(pd->file->read(fd, buf, len))
#define lseek(fd, offset, whence) pd_lseek(fd, offset, whence)

#endif