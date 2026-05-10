        .import osbyte_entry

        .segment "MOS_VECTORS"
; this is $ffb9 up to $fff9

.import gsinit_entry
.import gsread_entry
.import nvrdch_entry
.import nvwrch_entry
.import osargs_entry
.import osbget_entry
.import osbput_entry
.import osbyte_entry
.import oscli_entry
.import oseven_entry
.import osfile_entry
.import osfind_entry
.import osgbpb_entry
.import osrdch_entry
.import osrdrm_entry
.import osword_entry
.import oswrch_entry

.import unknown_entry

osrdrm_vector:  jmp osrdrm_entry
                jmp unknown_entry
oseven_vector:  jmp oseven_entry
gsinit_vector:  jmp gsinit_entry
gsread_vector:  jmp gsread_entry
nvwrch_vector:  jmp nvwrch_entry
nvrdch_vector:  jmp nvrdch_entry
osfind_vector:  jmp osfind_entry
osgbpb_vector:  jmp osgbpb_entry
osbput_vector:  jmp osbput_entry
osbget_vector:  jmp osbget_entry
osargs_vector:  jmp osargs_entry
osfile_vector:  jmp osfile_entry
osrdch_vector:  jmp osrdch_entry
osasci_vector:  cmp #$0d
                bne oswrch_vector
osnewl_vector:  lda #$0a
                jsr oswrch_vector
                lda #$0d
oswrch_vector:  jmp oswrch_entry
osword_vector:  jmp osword_entry
osbyte_vector:  jmp osbyte_entry
oscli_vector:   jmp oscli_entry
