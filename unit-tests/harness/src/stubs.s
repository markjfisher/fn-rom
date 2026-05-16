.export h_nvrdch_entry
.export h_nvwrch_entry
.export h_osargs_entry
.export h_osbget_entry
.export h_osbput_entry
.export h_oscli_entry
.export h_oseven_entry
.export h_osfile_entry
.export h_osfind_entry
.export h_osgbpb_entry
.export h_osrdch_entry
.export h_osrdrm_entry
.export h_osword_entry
.export h_unknown_entry

h_osrdrm_entry:
h_oseven_entry:
h_nvwrch_entry:
h_nvrdch_entry:
h_osfind_entry:
h_osgbpb_entry:
h_osbput_entry:
h_osbget_entry:
h_osargs_entry:
h_osfile_entry:
h_osrdch_entry:
h_osword_entry:
h_oscli_entry:

h_unknown_entry:
        ; force emulator to stop so we can inpect which entry was triggered
        brk
