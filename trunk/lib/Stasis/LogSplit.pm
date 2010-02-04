# Copyright (c) 2008, Gian Merlino
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package Stasis::LogSplit;

use strict;
use warnings;
use POSIX;
use Carp;

use Stasis::MobUtil;
use Stasis::Event qw/:constants/;

use constant {
    # After a boss is killed, don't allow another one of the same type to 
    # start for this long (seconds).
    LOCKOUT_TIME => 900,
};

our %zones = (
    "karazhan" => "Karazhan",
    "zulaman" => "Zul'Aman",
    "gruul" => "Gruul's Lair",
    "magtheridon" => "Magtheridon's Lair",
    "serpentshrine" => "Serpentshrine Cavern",
    "tempestkeep" => "Tempest Keep",
    "hyjal" => "Hyjal Summit",
    "blacktemple" => "Black Temple",
    "sunwell" => "Sunwell Plateau",
    "naxxramas" => "Naxxramas",
    "obsidiansanctum" => "Obsidian Sanctum",
    "archavon" => "Vault of Archavon",
    "eyeofeternity" => "The Eye of Eternity",
    "ulduar" => "Ulduar",
    "coliseum" => "Crusaders' Coliseum",
    "onyxia" => "Onyxia's Lair",
    "icecrown" => "Icecrown Citadel",
);

# Fingerprints of various boss encounters.
our @fingerprints = (

############
# KARAZHAN #
############

{
    short => "attumen",
    zone => "karazhan",
    long => "Attumen the Huntsman",
    mobStart => [ 16151, "Midnight" ],
    mobContinue => [ 15550, 16151, 16152, "Attumen the Huntsman", "Midnight" ],
    mobEnd => [ 16152, "Attumen the Huntsman" ],
    timeout => 30,
},

{
    short => "moroes",
    zone => "karazhan",
    long => "Moroes",
    mobStart => [ 15687, "Moroes" ],
    mobContinue => [ 15687, "Moroes" ],
    mobEnd => [ 15687, "Moroes" ],
    timeout => 30,
},

{
    short => "maiden",
    zone => "karazhan",
    long => "Maiden of Virtue",
    mobStart => [ 16457, "Maiden of Virtue" ],
    mobContinue => [ 16457, "Maiden of Virtue" ],
    mobEnd => [ 16457, "Maiden of Virtue" ],
    timeout => 30,
},

{
    short => "crone",
    zone => "karazhan",
    long => "Opera (Wizard of Oz)",
    mobStart => [ 17535, 17548, 17543, 17547, 17546, "Dorothee", "Tito", "Strawman", "Tinhead", "Roar" ],
    mobContinue => [ 17535, 17548, 17543, 17547, 17546, 18168, "Dorothee", "Tito", "Strawman", "Tinhead", "Roar", "The Crone" ],
    mobEnd => [ 18168, "The Crone" ],
    timeout => 30,
},

{
    short => "romulo",
    zone => "karazhan",
    long => "Opera (Romulo and Julianne)",
    mobStart => [ 17534, "Julianne" ],
    mobContinue => [ 17533, 17534, "Romulo", "Julianne" ],
    mobEnd => [ 17533, 17534 ],
    endAll => 1,
    timeout => 30,
},

{
    short => "bbw",
    zone => "karazhan",
    long => "Opera (Red Riding Hood)",
    mobStart => [ 17521, "The Big Bad Wolf" ],
    mobContinue => [ 17521, "The Big Bad Wolf" ],
    mobEnd => [ 17521, "The Big Bad Wolf" ],
    timeout => 30,
},

{
    short => "nightbane",
    zone => "karazhan",
    long => "Nightbane",
    mobStart => [ 17225, "Nightbane" ],
    mobContinue => [ 17225, 17261, "Nightbane", "Restless Skeleton" ],
    mobEnd => [ 17225, "Nightbane" ],
    timeout => 30,
},

{
    short => "curator",
    zone => "karazhan",
    long => "The Curator",
    mobStart => [ 15691, "The Curator" ],
    mobContinue => [ 15691, "The Curator" ],
    mobEnd => [ 15691, "The Curator" ],
    timeout => 30,
},

{
    short => "shade",
    zone => "karazhan",
    long => "Shade of Aran",
    mobStart => [ 16524, "Shade of Aran" ],
    mobContinue => [ 16524, "Shade of Aran" ],
    mobEnd => [ 16524, "Shade of Aran" ],
    timeout => 30,
},

{
    short => "illhoof",
    zone => "karazhan",
    long => "Terestian Illhoof",
    mobStart => [ 15688, "Terestian Illhoof" ],
    mobContinue => [ 15688, "Terestian Illhoof" ],
    mobEnd => [ 15688, "Terestian Illhoof" ],
    timeout => 30,
},

{
    short => "netherspite",
    zone => "karazhan",
    long => "Netherspite",
    mobStart => [ 15689, "Netherspite" ],
    mobContinue => [ 15689, "Netherspite" ],
    mobEnd => [ 15689, "Netherspite" ],
    timeout => 45,
},

{
    short => "prince",
    zone => "karazhan",
    long => "Prince Malchezaar",
    mobStart => [ 15690, "Prince Malchezaar" ],
    mobContinue => [ 15690, "Prince Malchezaar" ],
    mobEnd => [ 15690, "Prince Malchezaar" ],
    timeout => 30,
},

{
    short => "tenris",
    zone => "karazhan",
    long => "Tenris Mirkblood",
    mobStart => [ 28194 ],
    mobContinue => [ 28194 ],
    mobEnd => [ 28194 ],
    timeout => 30,
},

############
# ZUL'AMAN #
############

{
    short => "nalorakk",
    zone => "zulaman",
    long => "Nalorakk",
    mobStart => [ 23576, "Nalorakk" ],
    mobContinue => [ 23576, "Nalorakk" ],
    mobEnd => [ 23576, "Nalorakk" ],
    timeout => 30,
},

{
    short => "janalai",
    zone => "zulaman",
    long => "Jan'alai",
    mobStart => [ 23578, "Jan'alai" ],
    mobContinue => [ 23578, "Jan'alai" ],
    mobEnd => [ 23578, "Jan'alai" ],
    timeout => 30,
},

{
    short => "akilzon",
    zone => "zulaman",
    long => "Akil'zon",
    mobStart => [ 23574, "Akil'zon" ],
    mobContinue => [ 23574, "Akil'zon" ],
    mobEnd => [ 23574, "Akil'zon" ],
    timeout => 30,
},

{
    short => "halazzi",
    zone => "zulaman",
    long => "Halazzi",
    mobStart => [ 23577, "Halazzi" ],
    mobContinue => [ 23577, "Halazzi" ],
    mobEnd => [ 23577, "Halazzi" ],
    timeout => 30,
},

{
    short => "hexlord",
    zone => "zulaman",
    long => "Hex Lord Malacrass",
    mobStart => [ 24239, "Hex Lord Malacrass" ],
    mobContinue => [ 24239, "Hex Lord Malacrass" ],
    mobEnd => [ 24239, "Hex Lord Malacrass" ],
    timeout => 30,
},

{
    short => "zuljin",
    zone => "zulaman",
    long => "Zul'jin",
    mobStart => [ 23863, "Zul'jin" ],
    mobContinue => [ 23863, "Zul'jin" ],
    mobEnd => [ 23863, "Zul'jin" ],
    timeout => 30,
},

#################
# GRUUL AND MAG #
#################

{
    short => "maulgar",
    zone => "gruul",
    long => "High King Maulgar",
    mobStart => [ 18831, "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobContinue => [ 18831, "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobEnd => [ 18831, "High King Maulgar" ],
    timeout => 30,
},

{
    short => "gruul",
    zone => "gruul",
    long => "Gruul the Dragonkiller",
    mobStart => [ 19044, "Gruul the Dragonkiller" ],
    mobContinue => [ 19044, "Gruul the Dragonkiller" ],
    mobEnd => [ 19044, "Gruul the Dragonkiller" ],
    timeout => 30,
},

{
    short => "magtheridon",
    zone => "magtheridon",
    long => "Magtheridon",
    mobStart => [ 17256, "Hellfire Channeler" ],
    mobContinue => [ 17256, 17257, "Magtheridon", "Hellfire Channeler" ],
    mobEnd => [ 17257, "Magtheridon" ],
    timeout => 30,
},

########################
# SERPENTSHRINE CAVERN #
########################

{
    short => "hydross",
    zone => "serpentshrine",
    long => "Hydross the Unstable",
    mobStart => [ 21216, "Hydross the Unstable" ],
    mobContinue => [ 21216, "Hydross the Unstable" ],
    mobEnd => [ 21216, "Hydross the Unstable" ],
    timeout => 30,
},

{
    short => "lurker",
    zone => "serpentshrine",
    long => "The Lurker Below",
    mobStart => [ 21217, "The Lurker Below" ],
    mobContinue => [ 21217, 21865, 21873, "The Lurker Below", "Coilfang Ambusher", "Coilfang Guardian" ],
    mobEnd => [ 21217, "The Lurker Below" ],
    timeout => 30,
},

{
    short => "leotheras",
    zone => "serpentshrine",
    long => "Leotheras the Blind",
    mobStart => [ 21806, "Greyheart Spellbinder" ],
    mobContinue => [ 21806, 21215, "Greyheart Spellbinder", "Leotheras the Blind" ],
    mobEnd => [ 21215, "Leotheras the Blind" ],
    timeout => 30,
},

{
    short => "flk",
    zone => "serpentshrine",
    long => "Fathom-Lord Karathress",
    mobStart => [ 21214, "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobContinue => [ 21214, "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobEnd => [ 21214, "Fathom-Lord Karathress" ],
    timeout => 30,
},

{
    short => "tidewalker",
    zone => "serpentshrine",
    long => "Morogrim Tidewalker",
    mobStart => [ 21213, "Morogrim Tidewalker" ],
    mobContinue => [ 21213, "Morogrim Tidewalker" ],
    mobEnd => [ 21213, "Morogrim Tidewalker" ],
    timeout => 30,
},

{
    short => "vashj",
    zone => "serpentshrine",
    long => "Lady Vashj",
    mobStart => [ 21212, "Lady Vashj" ],
    mobContinue => [ 21212, 21958, 22056, 22055, 22009, "Lady Vashj", "Enchanted Elemental", "Tainted Elemental", "Coilfang Strider", "Coilfang Elite" ],
    mobEnd => [ 21212, "Lady Vashj" ],
    timeout => 30,
},

################
# TEMPEST KEEP #
################

{
    short => "alar",
    zone => "tempestkeep",
    long => "Al'ar",
    mobStart => [ 19514, "Al'ar" ],
    mobContinue => [ 19514, "Al'ar" ],
    mobEnd => [ 19514, "Al'ar" ],
    timeout => 45,
},

{
    short => "vr",
    zone => "tempestkeep",
    long => "Void Reaver",
    mobStart => [ 19516, "Void Reaver" ],
    mobContinue => [ 19516, "Void Reaver" ],
    mobEnd => [ 19516, "Void Reaver" ],
    timeout => 30,
},

{
    short => "solarian",
    zone => "tempestkeep",
    long => "High Astromancer Solarian",
    mobStart => [ 18805, "High Astromancer Solarian" ],
    mobContinue => [ 18805, 18806, 18925, "High Astromancer Solarian", "Solarium Priest", "Solarium Agent" ],
    mobEnd => [ 18805, "High Astromancer Solarian" ],
    timeout => 30,
},

{
    short => "kaelthas",
    zone => "tempestkeep",
    long => "Kael'thas Sunstrider",
    mobStart => [ 21272, 21273, 21269, 21268, 21274, 21271, 21270, "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser" ],
    mobContinue => [ 19622, 21272, 21273, 21269, 21268, 21274, 21271, 21270, 20063, 20062, 20064, 20060, "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser", "Kael'thas Sunstrider", "Phoenix", "Phoenix Egg", "Master Engineer Telonicus", "Grand Astromancer Capernian", "Thaladred the Darkener", "Lord Sanguinar" ],
    mobEnd => [ 19622, "Kael'thas Sunstrider" ],
    timeout => 60,
},

#########
# HYJAL #
#########

{
    short => "rage",
    zone => "hyjal",
    long => "Rage Winterchill",
    mobStart => [ 17767, "Rage Winterchill" ],
    mobContinue => [ 17767, "Rage Winterchill" ],
    mobEnd => [ 17767, "Rage Winterchill" ],
    timeout => 30,
},

{
    short => "anetheron",
    zone => "hyjal",
    long => "Anetheron",
    mobStart => [ 17808, "Anetheron" ],
    mobContinue => [ 17808, "Anetheron" ],
    mobEnd => [ 17808, "Anetheron" ],
    timeout => 30,
},

{
    short => "kazrogal",
    zone => "hyjal",
    long => "Kaz'rogal",
    mobStart => [ 17888, "Kaz'rogal" ],
    mobContinue => [ 17888, "Kaz'rogal" ],
    mobEnd => [ 17888, "Kaz'rogal" ],
    timeout => 30,
},

{
    short => "azgalor",
    zone => "hyjal",
    long => "Azgalor",
    mobStart => [ 17842, "Azgalor" ],
    mobContinue => [ 17842, "Azgalor" ],
    mobEnd => [ 17842, "Azgalor" ],
    timeout => 30,
},

{
    short => "archimonde",
    zone => "hyjal",
    long => "Archimonde",
    mobStart => [ 17968, "Archimonde" ],
    mobContinue => [ 17968, "Archimonde" ],
    mobEnd => [ 17968, "Archimonde" ],
    timeout => 30,
},

################
# BLACK TEMPLE #
################

{
    short => "najentus",
    zone => "blacktemple",
    long => "High Warlord Naj'entus",
    mobStart => [ 22887, "High Warlord Naj'entus" ],
    mobContinue => [ 22887, "High Warlord Naj'entus" ],
    mobEnd => [ 22887, "High Warlord Naj'entus" ],
    timeout => 30,
},

{
    short => "supremus",
    zone => "blacktemple",
    long => "Supremus",
    mobStart => [ 22898, "Supremus" ],
    mobContinue => [ 22898, "Supremus" ],
    mobEnd => [ 22898, "Supremus" ],
    timeout => 30,
},

{
    short => "akama",
    zone => "blacktemple",
    long => "Shade of Akama",
    mobStart => [ 23421, 23524, 23523, 23318, "Ashtongue Channeler", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue" ],
    mobContinue => [ 23421, 23524, 23523, 23318, 22841, "Ashtongue Channeler", "Ashtongue Defender", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue", "Shade of Akama" ],
    mobEnd => [ 22841, "Shade of Akama" ],
    timeout => 30,
},

{
    short => "teron",
    zone => "blacktemple",
    long => "Teron Gorefiend",
    mobStart => [ 22871, "Teron Gorefiend" ],
    mobContinue => [ 22871, "Teron Gorefiend" ],
    mobEnd => [ 22871, "Teron Gorefiend" ],
    timeout => 30,
},

{
    short => "bloodboil",
    zone => "blacktemple",
    long => "Gurtogg Bloodboil",
    mobStart => [ 22948, "Gurtogg Bloodboil" ],
    mobContinue => [ 22948, "Gurtogg Bloodboil" ],
    mobEnd => [ 22948, "Gurtogg Bloodboil" ],
    timeout => 30,
},

{
    short => "ros",
    zone => "blacktemple",
    long => "Reliquary of Souls",
    mobStart => [ 23418, "Essence of Suffering" ],
    mobContinue => [ 23418, 23419, 23420, 23469, "Essence of Suffering", "Essence of Desire", "Essence of Anger", "Enslaved Soul" ],
    mobEnd => [ 23420, "Essence of Anger" ],
    timeout => 30,
},

{
    short => "shahraz",
    zone => "blacktemple",
    long => "Mother Shahraz",
    mobStart => [ 22947, "Mother Shahraz" ],
    mobContinue => [ 22947, "Mother Shahraz" ],
    mobEnd => [ 22947, "Mother Shahraz" ],
    timeout => 30,
},

{
    short => "council",
    zone => "blacktemple",
    long => "Illidari Council",
    mobStart => [ 22950, 22952, 22951, 22949, "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobContinue => [ 22950, 22952, 22951, 22949, "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobEnd => [ 22950, 22952, 22951, 22949, 23426, "The Illidari Council" ],
    timeout => 30,
},

{
    short => "illidan",
    zone => "blacktemple",
    long => "Illidan Stormrage",
    mobStart => [ 22917, "Illidan Stormrage" ],
    mobContinue => [ 22917, 22997, "Illidan Stormrage", "Flame of Azzinoth" ],
    mobEnd => [ 22917, "Illidan Stormrage" ],
    timeout => 45,
},

###########
# SUNWELL #
###########

{
    short => "kalecgos",
    zone => "sunwell",
    long => "Kalecgos",
    mobStart => [ 24850 ],
    mobContinue => [ 24850, 24892 ],
    mobEnd => [ 24892 ],
    timeout => 30,
},

{
    short => "brutallus",
    zone => "sunwell",
    long => "Brutallus",
    mobStart => [ 24882 ],
    mobContinue => [ 24882 ],
    mobEnd => [ 24882 ],
    timeout => 30,
},

{
    short => "felmyst",
    zone => "sunwell",
    long => "Felmyst",
    mobStart => [ 25038 ],
    mobContinue => [ 25038, 25268 ],
    mobEnd => [ 25038 ],
    timeout => 45,
},

{
    short => "twins",
    zone => "sunwell",
    long => "Eredar Twins",
    mobStart => [ 25166, 25165 ],
    mobContinue => [ 25166, 25165 ],
    mobEnd => [ 25166, 25165 ],
    timeout => 30,
    endAll => 1,
},

{
    short => "muru",
    zone => "sunwell",
    long => "M'uru",
    mobStart => [ 25741 ],
    mobContinue => [ 25741, 25840, 25798, 25799 ],
    mobEnd => [ 25840 ],
    timeout => 30,
},

{
    short => "kiljaeden",
    zone => "sunwell",
    long => "Kil'jaeden",
    mobStart => [ 25315 ],
    mobContinue => [ 25315 ],
    mobEnd => [ 25315 ],
    timeout => 30,
},

#############
# NAXXRAMAS #
#############

{
    short => "anubrekhan",
    zone => "naxxramas",
    long => "Anub'Rekhan",
    mobStart => [ 15956 ],
    mobContinue => [ 15956 ],
    mobEnd => [ 15956 ],
    timeout => 30,
},

{
    short => "faerlina",
    zone => "naxxramas",
    long => "Grand Widow Faerlina",
    mobStart => [ 15953 ],
    mobContinue => [ 15953 ],
    mobEnd => [ 15953 ],
    timeout => 30,
},

{
    short => "maexxna",
    zone => "naxxramas",
    long => "Maexxna",
    mobStart => [ 15952 ],
    mobContinue => [ 15952, 17055 ],
    mobEnd => [ 15952 ],
    timeout => 30,
},

{
    short => "patchwerk",
    zone => "naxxramas",
    long => "Patchwerk",
    mobStart => [ 16028 ],
    mobContinue => [ 16028 ],
    mobEnd => [ 16028 ],
    timeout => 30,
},

{
    short => "grobbulus",
    zone => "naxxramas",
    long => "Grobbulus",
    mobStart => [ 15931 ],
    mobContinue => [ 15931 ],
    mobEnd => [ 15931 ],
    timeout => 30,
},

{
    short => "gluth",
    zone => "naxxramas",
    long => "Gluth",
    mobStart => [ 15932 ],
    mobContinue => [ 15932, 16360 ],
    mobEnd => [ 15932 ],
    timeout => 30,
},

{
    short => "thaddius",
    zone => "naxxramas",
    long => "Thaddius",
    mobStart => [ 15928, 15929, 15930 ],
    mobContinue => [ 15928, 15929, 15930 ],
    mobEnd => [ 15928 ],
    timeout => 30,
},

{
    short => "razuvious",
    zone => "naxxramas",
    long => "Instructor Razuvious",
    mobStart => [ 16061 ],
    mobContinue => [ 16061, 16803 ],
    mobEnd => [ 16061 ],
    timeout => 30,
},

{
    short => "gothik",
    zone => "naxxramas",
    long => "Gothik the Harvester",
    mobStart => [ 16124, 16125, 16126, 16127, 16148, 16150, 16149 ],
    mobContinue => [ 16060, 16124, 16125, 16126, 16127, 16148, 16150, 16149 ],
    mobEnd => [ 16060 ],
    timeout => 30,
},

{
    short => "horsemen",
    zone => "naxxramas",
    long => "Four Horsemen",
    mobStart => [ 16064, 16065, 30549, 16063 ],
    mobContinue => [ 16064, 16065, 30549, 16063 ],
    mobEnd => [ 16064, 16065, 30549, 16063 ],
    timeout => 30,
    endAll => 1,
},

{
    short => "noth",
    zone => "naxxramas",
    long => "Noth the Plaguebringer",
    mobStart => [ 15954 ],
    mobContinue => [ 15954, 16983, 16981 ],
    mobEnd => [ 15954 ],
    timeout => 30,
},

{
    short => "heigan",
    zone => "naxxramas",
    long => "Heigan the Unclean",
    mobStart => [ 15936 ],
    mobContinue => [ 15936, 16236 ],
    mobEnd => [ 15936 ],
    timeout => 60,
},

{
    short => "loatheb",
    zone => "naxxramas",
    long => "Loatheb",
    mobStart => [ 16011 ],
    mobContinue => [ 16011 ],
    mobEnd => [ 16011 ],
    timeout => 30,
},

{
    short => "sapphiron",
    zone => "naxxramas",
    long => "Sapphiron",
    mobStart => [ 15989 ],
    mobContinue => [ 15989, 16474 ],
    mobEnd => [ 15989 ],
    timeout => 60,
},

{
    short => "kelthuzad",
    zone => "naxxramas",
    long => "Kel'thuzad",
    mobStart => [ 15990, 16427, 16428, 16429 ],
    mobContinue => [ 15990, 16427, 16428, 16429, 16441 ],
    mobEnd => [ 15990 ],
    timeout => 30,
},

##################
# OUTDOOR BOSSES #
##################

{
    short => "kazzak",
    long => "Doom Lord Kazzak",
    mobStart => [ 18728 ],
    mobContinue => [ 18728 ],
    mobEnd => [ 18728 ],
    timeout => 15,
},

{
    short => "doomwalker",
    long => "Doomwalker",
    mobStart => [ 17711 ],
    mobContinue => [ 17711 ],
    mobEnd => [ 17711 ],
    timeout => 15,
},

##########################
# SINGLE BOSS ENCOUNTERS #
##########################

{
    short       => "sartharion",
    zone        => "obsidiansanctum",
    long        => "Sartharion",
    mobStart    => [ 28860 ],
    mobContinue => [ 28860, 31218, 31219 ],
    mobEnd      => [ 28860 ],
    timeout     => 45,
},

{
    short       => "archavon",
    zone        => "archavon",
    long        => "Archavon",
    mobStart    => [ 31125 ],
    mobContinue => [ 31125 ],
    mobEnd      => [ 31125 ],
    timeout     => 30,
},

{
    short       => "emalon",
    zone        => "archavon",
    long        => "Emalon",
    mobStart    => [ 33993 ],
    mobContinue => [ 33993, 33998 ],
    mobEnd      => [ 33993 ],
    timeout     => 30,
},

{
    short       => "koralon",
    zone        => "archavon",
    long        => "Koralon",
    mobStart    => [ 35013 ],
    mobContinue => [ 35013 ],
    mobEnd      => [ 35013 ],
    timeout     => 30,
},

{
    short       => "toravon",
    zone        => "archavon",
    long        => "Toravon",
    mobStart    => [ 38433 ],
    mobContinue => [ 38433 ],
    mobEnd      => [ 38433 ],
    timeout     => 30,
},

{
    short       => "malygos",
    zone        => "eyeofeternity",
    long        => "Malygos",
    mobStart    => [ 28859 ],
    mobContinue => [ 28859, 30161, 30249 ],
    mobEnd      => [ 28859 ],
    timeout     => 50,
},

{
    short       => "onyxia",
    zone        => "onyxia",
    long        => "Onyxia",
    mobStart    => [ 10184 ],
    mobContinue => [ 10184, 11262, 36561] ,
    mobEnd      => [ 10184 ],
    timeout     => 30,
},

##################
# TARGET DUMMIES #
##################

{
    short       => "dummy",
    long        => "Target Dummy",
    mobStart    => [ 31146, 30527, 31144 ],
    mobContinue => [ 31146, 30527, 31144 ],
    mobEnd      => [ ],
    timeout     => 30,
},

##########
# ULDUAR #
##########

{
    short       => "flameleviathan",
    zone        => "ulduar",
    long        => "Flame Leviathan",
    mobStart    => [ 33113 ],
    mobContinue => [ 33113 ],
    mobEnd      => [ 33113 ],
    timeout     => 15,
},

{
    short       => "ignis",
    zone        => "ulduar",
    long        => "Ignis the Furnace Master",
    mobStart    => [ 33118 ],
    mobContinue => [ 33118 ],
    mobEnd      => [ 33118 ],
    timeout     => 15,
},

{
    short       => "razorscale",
    zone        => "ulduar",
    long        => "Razorscale",
    mobStart    => [ 33186 ],
    mobContinue => [ 33186, 33388, 33846, 33453 ],
    mobEnd      => [ 33186 ],
    timeout     => 15,
},

{
    short       => "xt002",
    zone        => "ulduar",
    long        => "XT-002 Deconstructor",
    mobStart    => [ 33293 ],
    mobContinue => [ 33293, 33343, 33344, 33346, 33329 ],
    mobEnd      => [ 33293 ],
    timeout     => 20,
},

{
    short       => "ironcouncil",
    zone        => "ulduar",
    long        => "The Iron Council",
    mobStart    => [ 32927, 32857, 32867 ],
    mobContinue => [ 32927, 32857, 32867 ],
    mobEnd      => [ 32927, 32857, 32867 ],
    timeout     => 20,
    endAll      => 1,
},

{
    short       => "kologarn",
    zone        => "ulduar",
    long        => "Kologarn",
    mobStart    => [ 32930, 32933, 32934 ],
    mobContinue => [ 32930, 32933, 32934 ],
    mobEnd      => [ 32930 ],
    timeout     => 15,
},

{
    short       => "auriaya",
    zone        => "ulduar",
    long        => "Auriaya",
    mobStart    => [ 33515 ],
    mobContinue => [ 33515, 34034, 34014, 34035 ],
    mobEnd      => [ 33515 ],
    timeout     => 15,
},

{
    short       => "mimiron",
    zone        => "ulduar",
    long        => "Mimiron",
    mobStart    => [ 33432 ],
    mobContinue	=> [ 33432, 33651, 33670, 33836, 34057, 33855 ],
    mobEnd      => [ 33432, 33651, 33670 ],
    timeout     => 70,
    endAll      => 1,
},

{
    short       => "freya",
    zone        => "ulduar",
    long        => "Freya",
    mobStart    => [ 32906 ],
    mobContinue => [ 32906, 33203, 33202, 32918, 33228, 33215, 32916, 32919 ],
    mobEnd      => [ 32906 ],
    endFriendly => 1,
    timeout     => 15,
},

{
    short       => "thorim",
    zone        => "ulduar",
    long        => "Thorim",
    mobStart    => [ 32865, 32876, 32904, 32878, 32877 ],
    mobContinue => [ 32865, 32876, 32904, 32878, 32877 ],
    mobEnd      => [ 32865 ],
    endFriendly => 1,
    timeout     => 15,
},

{
    short       => "hodir",
    zone        => "ulduar",
    long        => "Hodir",
    mobStart    => [ 32845, 32938 ],
    mobContinue => [ 32845 ],
    mobEnd      => [ 32845 ],
    endFriendly => 1,
    timeout     => 20,
},

{
    short       => "vezax",
    zone        => "ulduar",
    long        => "General Vezax",
    mobStart    => [ 33271 ],
    mobContinue => [ 33271, 33524 ],
    mobEnd      => [ 33271 ],
    timeout     => 25,
},

{
    short       => "yoggsaron",
    zone        => "ulduar",
    long        => "Yogg-Saron",
    mobStart    => [ 33134 ],
    mobContinue => [ 33134, 33717, 33988, 33882, 33716, 33991, 33292, 33719, 33567, 33136, 33890, 33983, 33985, 33966, 33990, 33433, 33288 ],
    mobEnd      => [ 33288 ],
    timeout     => 30,
},

{
    short       => "algalon",
    zone        => "ulduar",
    long        => "Algalon the Observer",
    mobStart    => [ 32871 ],
    mobContinue => [ 32871, 32953, 32955, 33052, 33089 ],
    mobEnd      => [ 32871 ],
    endFriendly => 1,
    timeout     => 50,
},

############
# COLISEUM #
############

{
    short       => "northrendbeasts",
    zone        => "coliseum",
    long        => "Northrend Beasts",
    mobStart    => [ 34796 ],
    mobContinue => [ 34796, 34800, 35176, 34854, 34799, 35144, 34797 ],
    mobEnd      => [ 34797 ],
    timeout     => 30,
    heroic      => [ 67478, 67479 ], # Impale
    normal      => [ 66331, 67477 ], # Impale
},

{
    short       => "lordjaraxxus",
    zone        => "coliseum",
    long        => "Lord Jaraxxus",
    mobStart    => [ 34780 ],
    mobContinue => [ 34780, 34815, 34826 ],
    mobEnd      => [ 34780 ],
    timeout     => 30,
    heroic      => [ 67030, 67031 ], # Fel lightning
    normal      => [ 66528, 67029 ], # Fel lightning
},

{
    short       => "factionchampions",
    zone        => "coliseum",
    long        => "Faction Champions",
    mobStart    => [ 34453, 34454, 34455, 34456, 34458, 34441, 34448, 34449, 34450, 34451, 34444, 34445, 34447, 34459,      # Alliance NPCs (excl. pets)
                     34475, 34467, 34472, 34471, 34474, 34469, 34460, 34468, 34463, 34466, 34470, 34473, 34461, 34465 ],    # Horde NPCs (excl. pets)
    mobContinue => [ 34453, 34454, 34455, 34456, 34458, 34441, 34448, 34449, 34450, 34451, 34444, 34445, 34447, 34459,
                     34475, 34467, 34472, 34471, 34474, 34469, 34460, 34468, 34463, 34466, 34470, 34473, 34461, 34465 ],
    mobEnd      => [ 34453, 34454, 34455, 34456, 34458, 34441, 34448, 34449, 34450, 34451, 34444, 34445, 34447, 34459,
                     34475, 34467, 34472, 34471, 34474, 34469, 34460, 34468, 34463, 34466, 34470, 34473, 34461, 34465 ],
    endCount    => 6,
    timeout     => 30,
    heroic      => [ 65547 ], # PvP trinket
    normal      => [ 66019, 67929, 65926, 68782 ], # DK Death Coil or Warrior MS. Might need more? Someone ever fought them without either DK or Warrior?
},

{
    short       => "twinvalkyrs",
    zone        => "coliseum",
    long        => "Twin Valkyrs",
    mobStart    => [ 34496, 34497 ],
    mobContinue => [ 34496, 34497 ],
    mobEnd      => [ 34496, 34497 ],
    timeout     => 30,
    endAll      => 1,
    heroic      => [ 67266, 67267 ], # Dark surge
    normal      => [ 65769, 67265 ], # Dark surge
},

{
   short       => "anubarak",
   zone        => "coliseum",
   long        => "Anub'arak",
   mobStart    => [ 34564 ],
   mobContinue => [ 34564, 34605, 34606, 34607 ],
   mobEnd      => [ 34564 ],
   timeout     => 30,
   endAll      => 1,
   heroic      => [ 68509, 68510 ], # Penetrating cold
   normal      => [ 66013, 67700 ], # Penetrating cold
},

############
# ICC #
############
{
	short		=> "marrowgar",
	zone		=> "icecrown",
	long		=> "Lord Marrowgar",
	mobStart	=> [ 36612 ],
	mobContinue	=> [ 36612 ],
	mobEnd		=> [ 36612 ],
	timeout		=> 30,
	endAll      => 1,
	heroic		=> [ 70824, 70825], # Coldflame
	normal		=> [ 69146, 70823], # Coldflame
},
{
	short		=> "deathwhisper",
	zone		=> "icecrown",
	long		=> "Lady Deathwhisper",
	mobStart	=> [ 36855 ],
	mobContinue	=> [ 36855, 37949, 37890 ],
	mobEnd		=> [ 36855 ],
	timeout		=> 30,
	endAll      => 1,
	heroic		=> [], # Frostbolt
	normal		=> [72007], # Frostbolt
	
},
{
	short		=> "gunship",
	zone		=> "icecrown",
	long		=> "Gunship",
	mobStart	=> [ 37215, 37540 ],
	mobContinue	=> [ 37215, 37540 ],
	mobEnd		=> [ 37215, 37540 ],
	timeout		=> 30,
	heroic		=> [ ], 
	normal		=> [ ], 
	
},
{
	short		=> "saurfang",
	zone		=> "icecrown",
	long		=> "Deathbringer Saurfang",
	mobStart	=> [ 37813  ],
	mobContinue	=> [ 37813, 38508 ],
	mobEnd		=> [ 37813 ],
	timeout		=> 30,
	heroic		=> [ ], #Boiling Blood
	normal		=> [ 72385, 72442], #Boiling Blood
	
},
{
	
	short		=> "rotface",
	zone		=> "icecrown",
	long		=> "Rotface",
	mobStart	=> [ 36627  ],
	mobContinue	=> [ 36627, 36899, 36897 ],
	mobEnd		=> [ 36627 ],
	timeout		=> 30,
	heroic		=> [73022, 73023],#Mutated infection
	normal		=> [69674, 71224],#Mutated infection
	
},
{
	
	short		=> "festergut",
	zone		=> "icecrown",
	long		=> "Festergut",
	mobStart	=> [ 36626  ],
	mobContinue	=> [ 36626 ],
	mobEnd		=> [ 36626 ],
	timeout		=> 30,
	heroic		=> [ 72229, 72230 ], #Gastric Explosion
	normal		=> [ 72227 ], #Gastric Explosion
},
{
	
	short		=> "putricide",
	zone		=> "icecrown",
	long		=> "Professor Putricide",
	mobStart	=> [ 36678  ],
	mobContinue	=> [ 36678, 37672, 37562 ],
	mobEnd		=> [ 36678 ],
	timeout		=> 30,
	heroic		=> [ 72619 ], #Choking Gas
	normal		=> [ 71278 ], #Choking Gas
	
},
{
    short           => "bloodprince",
    zone            => "icecrown",
    long            => "Blood Prince Council",
    mobStart        => [ 37970, 37972, 37973 ],
    mobContinue     => [ 37970, 37972, 37973 ],
    mobEnd          => [ 37970, 37972, 37973 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],
    endAll      => 1,
},
{
    short           => "bloodqueen",
    zone            => "icecrown",
    long            => "Blood-Queen Lana'thel",
    mobStart        => [ 37955 ],
    mobContinue     => [ 37955 ],
    mobEnd          => [ 37955 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],
},
{
    short           => "valithria",
    zone            => "icecrown",
    long            => "Valithria Dreamwalker",
    mobStart        => [ 37868 ],
    mobContinue     => [ 36789, 37868],
    mobEnd          => [ 36789 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],
	endFriendly		=> 1,
	endUltimate		=> 1,

},
{
    short           => "sindragosa",
    zone            => "icecrown",
    long            => "Sindragosa",
    mobStart        => [ 36853 ],
    mobContinue     => [ 36853 ],
    mobEnd          => [ 36853 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

},

{
    short           => "theking",
    zone            => "icecrown",
    long            => "The Lich King",
    mobStart        => [ 29983 ],
    mobContinue     => [ 29983 ],
    mobEnd          => [ 29983 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

},

###################
# ICC MINI BOSSES #
###################
{
    short           => "stinky",
    zone            => "icecrown",
    long            => "Stinky",
    mobStart        => [ 37025 ],
    mobContinue     => [ 37025 ],
    mobEnd          => [ 37025 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

},
{
    short           => "precious",
    zone            => "icecrown",
    long            => "Precious",
    mobStart        => [ 37217 ],
    mobContinue     => [ 37217 ],
    mobEnd          => [ 37217 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

},
{
    short           => "giant",
    zone            => "icecrown",
    long            => "Rotting Frost Giant",
    mobStart        => [ 38490 ],
    mobContinue     => [ 38490 ],
    mobEnd          => [ 38490 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

},
{
    short           => "svalna",
    zone            => "icecrown",
    long            => "Sister Svalna",
    mobStart        => [ 37126 ],
    mobContinue     => [ 37126 ],
    mobEnd          => [ 37126 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

},
{
    short           => "rimefang",
    zone            => "icecrown",
    long            => "Rimefang",
    mobStart        => [ 37533 ],
    mobContinue     => [ 37533 ],
    mobEnd          => [ 37533 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

},
{
    short           => "spinestalker",
    zone            => "icecrown",
    long            => "Spinestalker",
    mobStart        => [ 37534 ],
    mobContinue     => [ 37534 ],
    mobEnd          => [ 37534 ],
    timeout         => 30,
    heroic          => [ ],
    normal          => [ ],

}


);

# Create and invert the %hfingerprints hash.
my %hfingerprints;
$hfingerprints{ $_->{short} } = $_ foreach @fingerprints;

my %fstart;
my %fcontinue;
my %fend;

while( my ($kprint, $vprint) = each %hfingerprints ) {
    foreach (@{$vprint->{mobStart}}) {
        $fstart{$_} = $kprint;
    }
    
    foreach (@{$vprint->{mobContinue}}) {
        $fcontinue{$_} = $kprint;
    }
    
    foreach (@{$vprint->{mobEnd}}) {
        $fend{$_} = $kprint;
    }
}

sub new {
    my $class = shift;
    my %params = @_;
    
    delete $params{scratch};
    $params{splits} = [];
    
    # Lockout after kills
    $params{lockout} = {};
    
    # Callback sub
    $params{callback} ||= undef;
    
    bless \%params, $class;
}

sub register {
    my ( $self, $ed ) = @_;
    
    # Looks for when boss encounters begin and when bosses die.
    $ed->add(
        qw/SWING_DAMAGE SWING_MISSED RANGE_DAMAGE RANGE_MISSED SPELL_PERIODIC_DAMAGE SPELL_DAMAGE SPELL_MISSED UNIT_DIED UNIT_DESTROYED/,
        sub { $self->process( @_ ) }
    );
    
    # Looks for when boss attempts time out (usually because everyone in the raid died)
    $ed->add(
        qw/SPELL_AURA_APPLIED SPELL_AURA_REMOVED SPELL_CAST_SUCCESS/,
        sub { $self->process_timeout_check( @_ ) }
    );
    
    # Looks for spells to determine normal/heroic
    $ed->add(
        qw/SPELL_DAMAGE SPELL_PERIODIC_DAMAGE SPELL_CAST_SUCCESS/,
        sub { $self->process_heroic( @_ ) }
    );
}

sub process_heroic {
    my ($self, $event) = @_;
    
    if( my $vboss = $self->{scratch} ) {
        # Check if we determined the difficulty already.
        # This is what the normal array is for, to speed up the parsing of non-heroic fights.
        if( not defined $self->{scratch}{heroic} ) {
        
            foreach ( @{$hfingerprints{$vboss->{short}}{heroic}} ) {
                if( $_ == $event->{spellid} ) {
                    $vboss->{heroic} = 1;
                    return;
                }
            }
            
            foreach( @{$hfingerprints{$vboss->{short}}{normal}} ) {
                if( $_ == $event->{spellid} ) {
                    $vboss->{heroic} = 0;
                    return;
                }
            }
            
        }
    }
}

sub process_timeout_check {
    my ($self, $event) = @_;
    
    # Check for timeout.
    my $vboss;
    if( ( $vboss = $self->{scratch} ) && $event->{t} > $vboss->{end} + $vboss->{timeout} ) {
        
        # Check if enough mobs was killed for endCount to register it as a kill
        if( $hfingerprints{$vboss->{short}}{endCount} && $vboss->{count} >= $hfingerprints{$vboss->{short}}{endCount} ) {
            $self->_bend(
                {
                    short => $vboss->{short},
                    long  => $hfingerprints{$vboss->{short}}{long},
                    start => $vboss->{start},
                    end   => $vboss->{end},
                    kill  => 1,
                }
            );
        } else {
            # This fingerprint timed out without ending.
            # Record it as an attempt.
            
            $self->_bend(
                {
                    short => $vboss->{short},
                    long  => $hfingerprints{$vboss->{short}}{long},
                    start => $vboss->{start},
                    end   => $vboss->{end},
                    kill  => 0,
                }
            );
        }
        
        # 1 means timeout.
        return 1;
    }
    
    # 0 means no timeout.
    return 0;
}

sub process {
    my ($self, $event) = @_;
    
    # Figure out what to use for the actor and target identifiers.
    # This will be either the name (version 1) or the NPC part of the ID (version 2)
    
    my $actor_id = $event->{actor} ? (Stasis::MobUtil::splitguid( $event->{actor} ))[1] || $event->{actor} : 0;
    my $target_id = $event->{target} ? (Stasis::MobUtil::splitguid( $event->{target} ))[1] || $event->{target} : 0;
    
    # See if we should end, or continue, an encounter currently in progress.
    if( my $vboss = $self->{scratch} ) {
        my $kboss = $vboss->{short};
        
        if( ! $self->process_timeout_check( $event ) && ( ($fcontinue{$actor_id} && $fcontinue{$actor_id} eq $kboss) || ($fcontinue{$target_id} && $fcontinue{$target_id} eq $kboss) ) ) {
            # We should continue this encounter.
            $vboss->{end} = $event->{t};
            
            # Also possibly end it.
            if( ($event->{action} == UNIT_DIED || $event->{action} == UNIT_DESTROYED) && $fend{$target_id} && $fend{$target_id} eq $kboss ) {
                $vboss->{dead}{$target_id} = 1;
                $vboss->{count}++;
                
                if( !$hfingerprints{$kboss}{endCount} && ( !$hfingerprints{$kboss}{endAll} || ( scalar keys %{$vboss->{dead}} == scalar @{$hfingerprints{$kboss}{mobEnd}} ) ) ) {
                    $self->_bend(
                        {
                            short => $kboss,
                            long  => $hfingerprints{ $kboss }{long},
                            start => $vboss->{start},
                            end   => $vboss->{end},
                            kill  => 1,
                        }
                    );
                }
            }
            
            # Check if target turned friendly (Thorim, Freya, Hodir, et al.)
            elsif( $hfingerprints{$kboss}{endFriendly} ) {
                if( ($fend{$target_id} && $fend{$target_id} eq $kboss && ($event->{target_relationship} & 0xF0) == 16) ||
                    ($fend{$actor_id}  && $fend{$actor_id}  eq $kboss && ($event->{actor_relationship}  & 0xF0) == 16) ) 
                   { 
					if( $hfingerprints{$kboss}{endUltimate} && $event->{spellid} == 71189) 
					{                   
                    
                    $self->_bend(
                        {
                            short => $kboss,
                            long  => $hfingerprints{ $kboss }{long},
                            start => $vboss->{start},
                            end   => $vboss->{end},
                            kill  => 1,
                        }
                    );
					}
					elsif( !$hfingerprints{$kboss}{endUltimate})
					{                   
                    
                    $self->_bend(
                        {
                            short => $kboss,
                            long  => $hfingerprints{ $kboss }{long},
                            start => $vboss->{start},
                            end   => $vboss->{end},
                            kill  => 1,
                        }
                    );
					}
					}
            }
        }
    } else {
        # See if we should start a new encounter.
        if( $fstart{$actor_id} && ( !$self->{lockout}{ $fstart{$actor_id} } || $self->{lockout}{ $fstart{$actor_id} } < $event->{t} - 300 ) ) {
            # The actor should start a new encounter.
            $self->_bstart(
                {
                    short => $fstart{$actor_id},
                    long  => $hfingerprints{ $fstart{$actor_id} }{long},
                    start => $event->{t},
                    end   => undef,
                    kill  => undef,
                }
            );
        } elsif( $fstart{$target_id} && ( !$self->{lockout}{ $fstart{$target_id} } || $self->{lockout}{ $fstart{$target_id} } < $event->{t} - LOCKOUT_TIME ) ) {
            # The target should start a new encounter.
            $self->_bstart(
                {
                    short => $fstart{$target_id},
                    long  => $hfingerprints{ $fstart{$target_id} }{long},
                    start => $event->{t},
                    end   => undef,
                    kill  => undef,
                }
            );
        }
    }
}

sub _bstart {
    my ( $self, $boss ) = @_;
    
    # Create a scratch boss.
    $self->{scratch} = {
        short   => $boss->{short},
        timeout => $hfingerprints{ $boss->{short} }{timeout},
        start   => $boss->{start},
        end     => $boss->{start},
        count   => 0,
    };
    
    # Callback.
    $self->{callback}->( $boss ) if( $self->{callback} );
}

sub _bend {
    my ( $self, $boss ) = @_;

    # Record lockout time.
    $self->{lockout}{$boss->{short}} = $boss->{end} if $boss->{kill};
    
    # Save the heroic status
    $boss->{heroic} = $self->{scratch}{heroic};
    $boss->{long} = "Heroic: " . $boss->{long} if $boss->{heroic};

    # Delete scratch boss (so we are free to start another)
    delete $self->{scratch};

    # Record this split as being finished.
    push @{ $self->{splits} }, $boss;

    # Callback.
    $self->{callback}->( $boss ) if( $self->{callback} );
}

sub name {
    my $boss = pop;
    return $boss && $hfingerprints{$boss} && $hfingerprints{$boss}{long};
}

sub zone {
    my $boss = pop;
    return $boss && $hfingerprints{$boss} && $hfingerprints{$boss}{zone};
}

sub finish {
    my $self = shift;
    
    # End of the log file -- close up any open bosses.
    if( my $vboss = $self->{scratch} ) {
        $self->_bend(
            {
                short => $vboss->{short},
                long  => $hfingerprints{$vboss->{short}}{long},
                start => $vboss->{start},
                end   => $vboss->{end},
                kill  => 0,
            }
        );
    }
    
    # Return.
    return @{$self->{splits}};
}

1;