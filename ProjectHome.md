A fork of StasisCL (http://code.google.com/p/stasiscl/), advancing it with more recently submitted patches.

(original StasisCL description follows)

StasisCL is an open source, BSD licensed (see License) Perl application that parses WoW combat logs and generates statistics from them. The goal of the project is to generate static HTML reports that you host on your own web server. It should work on TBC logs as well as WLK logs.

I especially encourage you to look at healing reports and buff reports, which I feel are particularly strong (mostly due to expandability into spells for healing, and uptime for buffs). For example, you can see things like debuff uptime on the boss and spells used by each healer on a tank.

The best way to communicate a feature request or bug report is to open an issue (on the tab above). I'm pretty much guaranteed to remember it since it will stay in the list until I take a look. Read QuickStart to get going on a Mac or other Unix-like system. If you are on Windows, read QuickStartWindows. Make sure to check for updates from the SVN from time to time.

To briefly describe how this all works technically, for those of you interested: the actual "stasis" program does very little aside from gather command line options and glue modules together. Most of the work is done by a set of Perl modules in the "lib" directory, which are designed to be independent enough that you could use them in your own application.

If you'd rather do your own analysis, StasisCL can also convert log files into SQLite databases with a simple and easy-to-query schema, which you can then interact with however you desire.

The following Perl modules are used but not included:

File::Copy
File::Find
File::Path
File::Spec
Getopt::Long
HTML::Entities
File::Tail (only required when using -tail)
Many of these probably came with your perl distribution. The rest should be on CPAN.

### Plotting features ###
Plotting features are now available. The -plot argument must be supplied to enable them, and flot libraries from http://code.google.com/p/flot must be added to your extras folder.

### Logfile merging ###
A separate tool is now available for merging logfiles. It is run with options such as
merge -file1 logfile1.txt -file2 logfile2.txt -output merged.txt
For full information on the options, run 'perldoc merge' from the apostasis directory.
Once the merge is complete, apostasis (or any other log parser) should be run on the output as usual.

### Related projects ###
Various projects add functionality to Apostasis/StasisCL:
  * Wowspi adds graphical options to parses - http://wiki.github.com/wickedgrey/wowspi (example parse [here](http://www.gtguild.net/logs/bydate/2009-10-11/sws-yoggsaron-1255330845/index.html))
  * SCLA aids with archiving combat logs - http://misc.elitism-guild.com/scla/
  * SWSUtils - see http://tfu.ath.cx/.fuu/swsutils/ for various automation scripts