@echo off

cd\
cd E:\empty_sui\game\maps


echo Copying Files...
copy E:\empty_sui\game\maps\test.map E:\empty_sui\game\maps


echo Converting map...


echo --------------QBSP--------------
E:\mapping\tools\ericw-tools-v0.18-win32\bin\qbsp.exe test

echo --------------VIS---------------
E:\mapping\tools\ericw-tools-v0.18-win32\bin\vis.exe -fast test

echo -------------LIGHT--------------
E:\mapping\tools\ericw-tools-v0.18-win32\bin\light.exe -bounce -bouncescale 0.5 -dirt -dirtscale 1.0 -soft -extra test

copy test.bsp E:\empty_sui\game\maps
copy test.pts E:\empty_sui\game\maps
copy test.lit E:\empty_sui\game\maps
pause
