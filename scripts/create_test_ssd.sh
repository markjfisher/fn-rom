#!/bin/bash

rm -f test.ssd >/dev/null 2>&1
./scripts/create_ssd.py -i ./bas -o test.ssd
./scripts/mmfs2_manager.py remove ../mybeeb.img test.ssd
./scripts/mmfs2_manager.py add ../mybeeb.img test.ssd
