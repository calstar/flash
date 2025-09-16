Jetson Xavier Flashing Process:

1. Flash Jetson with rootfs via Command Line. Instructions found at https://wiki.seeedstudio.com/reComputer_A203_Flash_System/

2. Boot Xavier and run jetson_initial_flash.sh

    This script will reboot once after the rootfs is transfered to the SSD and will continue the installation process automatically. To monitor the progress after the reboot you can run this command in a terminal:
    $ sudo journalctl -u temp.service -f --output=cat

3. Once rebooted, run jetson_install_fsw.sh
    This will download the FSW repo and setup the reqs for the OpenCV install next

4. Run jetson_install_opencvcuda.sh 
    This will install opencv with cuda to your jetson

5. Run jetson_install_pyreqs_base.sh
    This will install python requirements needed for the system as well as tensorflow for gpu

> ⚠️ **Deprecated:** The steps below are kept for historical reference only. Step 3 above replaces this.
>
> ```bash
> #6. Clone fsw repo and build project:
> #    $ git clone --recurse-submodule https://git.singularityus.com/revere/fsw.git
> #    $ cd fsw
> #    $ mkdir build
> #    $ cd build
> #    $ cmake ..
> #    $ make -j6
> ```

This process can take up to three hours. Once complete, your jetson should be ready to go!

GroundStation Flashing Process:

1. run groundstation_install_fsw.sh
    This will download FSW and setup the reqs for the OpenCV install next

2. run groundstation_opencvcuda.sh
    This will install opencv with cuda to your laptop

3. run groundstation_install_pyreqs_base.sh
    This will install python requirements needed for the system as well as tensorflow for gpu (small GPU Issue currently, will only run on CPU)

Developer Hint:
Optional Bash Helper (bashdb -> Bash Debugger) for development. Can be installed by running bashdb_install.sh and is helpful in the creation of these scripts
