#include <endian.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <attr/xattr.h>
#include <linux/types.h>
#include <linux/capability.h>

#ifndef VFS_CAP_REVISION_3
struct vfs_ns_cap_data {
	__u32 magic_etc;
	struct {
		__u32 permitted;
		__u32 inheritable;
	} data[2];
	__u32 rootid;
};
#endif

// set cap_sys_admin=pe for the rootd in arg1 on file in arg2
int main(int argc, char *argv[])
{
	struct vfs_ns_cap_data v;
	int ret;
	int rootid;

	if (argc != 3)
		exit(1);
	rootid = atoi(argv[1]);
	memset(&v, 0, sizeof(v));

	v.rootid = htole32(rootid);
	v.data[0].permitted = htole32(1 << CAP_SYS_ADMIN);
	v.magic_etc = htole32(0x03000000 | 0x000001); // v3 cap and set effective
	ret = setxattr(argv[2], "security.capability", &v, sizeof(v), 0);
	if (ret < 0)
		exit(errno);
	exit(0);
}
