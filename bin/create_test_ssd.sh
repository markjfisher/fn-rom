#!/bin/bash

rm -f test.ssd >/dev/null 2>&1
./bin/create_ssd.py -i ./bas -o test.ssd
../b2/bin/mmfs2_manager.py remove ../mybeeb.img test.ssd
../b2/bin/mmfs2_manager.py add ../mybeeb.img test.ssd
