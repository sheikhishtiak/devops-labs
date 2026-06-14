
/ is the root
/bin -> usr/bin essential commands

/etc system-wide CONFIG file(text, editable)

/home regualr user's personal dirs

/opt self-contained third-party apps

/root root user's home

/tmp scratch space

/usr 
    /bin command installed by the package manager
    /local/bin command YOU install by hand

/var
    /lib app DATA that must survive restart
    /log LOG files

/proc virtual keenel's live process view

/sys virtual kernel's view of hardware/drivers

/etc/ is system-wide configuration files live here so any process can find them in one predictable place

/var/log/ logs are variable growing data and /var/ is designed for files that change in size during normal operation

Data /var/lib/ persistent application state and data (like database) belong here because it survives reboots and is separate from config

/usr/local/bin anything you install manually goes here to avoid conflicting with distro-managed binaries in /usr/bin

scratch /tmp/ temporary files that don't need to survive. 


#Both break-it moments: the exact error text you saw, why it happened, the fix command.

I had permission error after running "cp ~/webagent /usr/local/bin/webagent" because i am not allow to write expect read. To write i must need to use sudo.

another error i found that file doesn't exit. i worte the file name and path in the script file but i didn't create the file before it. 


When you pipe something with echo "text" | sudo tee /path/file, the sudo applies to tee (which does the writing), not to echo — so the file gets written with r…When you pipe something with echo "text" | sudo tee /path/file, the sudo applies to tee (which does the writing), not to echo — so the file gets written with root privileges even though your shell stays as a normal user.

command -v file  -> to find the path

sudo find path -name "value"

tail -n 5 /var/log/webagent/webagent.log



