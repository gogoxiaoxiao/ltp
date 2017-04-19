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

	if (argc != 2)
		exit(1);
	memset(&v, 0, sizeof(v));

	ret = getxattr(argv[1], "security.capability", &v, sizeof(v));
	if (ret == sizeof(v)) {
		printf("v3 xattr, rootid is %d\n", le32toh(v.rootid));
	} else if (ret == sizeof(struct vfs_cap_data)) {
		printf("v2 xattr\n");
	}
	if (ret < 0)
		exit(errno);
	exit(0);
}
