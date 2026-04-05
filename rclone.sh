rclone mount gdrive: /home/fabri/Documents/ --daemon \
--vfs-cache-mode full \
--dir-cache-time 1000h \
--buffer-size 64M \
--vfs-read-chunk-size 128M \
--vfs-read-chunk-size-limit 2G \
--drive-acknowledge-abuse

