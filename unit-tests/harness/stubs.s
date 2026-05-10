
.export gsinit_entry
.export gsread_entry
.export nvrdch_entry
.export nvwrch_entry
.export osargs_entry
.export osbget_entry
.export osbput_entry
.export oscli_entry
.export oseven_entry
.export osfile_entry
.export osfind_entry
.export osgbpb_entry
.export osrdch_entry
.export osrdrm_entry
.export osword_entry
.export oswrch_entry
.export unknown_entry

; if any of these are called, we will stop the emulator
osrdrm_entry:
oseven_entry:
gsinit_entry:
gsread_entry:
nvwrch_entry:
nvrdch_entry:
osfind_entry:
osgbpb_entry:
osbput_entry:
osbget_entry:
osargs_entry:
osfile_entry:
osrdch_entry:
oswrch_entry:
osword_entry:
oscli_entry:

unknown_entry:
                brk