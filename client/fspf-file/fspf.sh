#!/bin/bash

# create a file system protection file (first unencrypted)
scone fspf create /fspf/fspf-file/fs.fspf
# root region (i.e., "/") is not protected in this demo
scone fspf addr /fspf/fspf-file/fs.fspf / --not-protected --kernel /
# add encrypted region /fspf/encrypted-files
scone fspf addr /fspf/fspf-file/fs.fspf /fspf/encrypted-files/ --encrypted --kernel /fspf/encrypted-files/
# add all files in directory /fspf/native-files/ to /fspf/encrypted-files/
scone fspf addf /fspf/fspf-file/fs.fspf /fspf/encrypted-files/ /fspf/native-files/ /fspf/encrypted-files/ 
# finally, encrypt the file system protection file and store the keys in directory (we assume in this demo that wee run on a trusted host)
scone fspf encrypt /fspf/fspf-file/fs.fspf > /fspf/native-files/keytag
