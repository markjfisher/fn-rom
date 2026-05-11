        .import osbyte_entry

        .segment "MOS_VECTORS"
; this is $ffb9 up to $fff9

.import h_gsinit_entry
.import h_gsread_entry
.import h_nvrdch_entry
.import h_nvwrch_entry
.import h_osargs_entry
.import h_osbget_entry
.import h_osbput_entry
.import h_osbyte_entry
.import h_oscli_entry
.import h_oseven_entry
.import h_osfile_entry
.import h_osfind_entry
.import h_osgbpb_entry
.import h_osrdch_entry
.import h_osrdrm_entry
.import h_osword_entry
.import h_oswrch_entry

.import h_unknown_entry

osrdrm_vector:  jmp h_osrdrm_entry
                jmp h_unknown_entry
oseven_vector:  jmp h_oseven_entry
gsinit_vector:  jmp h_gsinit_entry
gsread_vector:  jmp h_gsread_entry
nvwrch_vector:  jmp h_nvwrch_entry
nvrdch_vector:  jmp h_nvrdch_entry
osfind_vector:  jmp h_osfind_entry
osgbpb_vector:  jmp h_osgbpb_entry
osbput_vector:  jmp h_osbput_entry
osbget_vector:  jmp h_osbget_entry
osargs_vector:  jmp h_osargs_entry
osfile_vector:  jmp h_osfile_entry
osrdch_vector:  jmp h_osrdch_entry
osasci_vector:  cmp #$0d
                bne oswrch_vector
osnewl_vector:  lda #$0a
                jsr oswrch_vector
                lda #$0d
oswrch_vector:  jmp h_oswrch_entry
osword_vector:  jmp h_osword_entry
osbyte_vector:  jmp h_osbyte_entry
oscli_vector:   jmp h_oscli_entry
