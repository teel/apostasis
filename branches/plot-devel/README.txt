This is a development branch of apostasis.

It enables plotting through the flot library -
http://code.google.com/p/flot/

The flot .js files must be placed in the extras directory. Plot output
is enabled by passing the -plot flag.

Current issues:
* plot values appear to be ~twice the correct value - hacking the code
to plot cumulative damage output for example shows the curve finishing
at ~twice the listed raid damage. This is the major issue that holds
up committing to the trunk.

* output files can be large and slow to parse. This is probably
unavoidable for the most part but might be alleviated in cases where
outputs are zero for a long stretch, e.g. between boss attempts in an
-overall parse. edit: patched in fix for long stretches of zeroes,
performance still low so might want to enforce smoothing on long 
parses, once smoothing is available.

* there are minor peculiarities with the interaction between tabbing
and plotting - flot does not handle well the situation where plots are
rendered in display:none divs. The current workaround is to set the
plot tab to be visible at the start. This won't work if multiple plot
tabs are ever added however.

Enhancements desired:
* denoting heroism/bloodlust

* provide option for moving average smoothing

* provide flot crosshair plugin support, to allow read-off of values
on plots.

EE 17/12/09
