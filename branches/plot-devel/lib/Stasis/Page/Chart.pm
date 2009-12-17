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

package Stasis::Page::Chart;

use strict;
use warnings;

use POSIX;
use HTML::Entities qw();

use Stasis::Page;
use Stasis::PageMaker;
use Stasis::ActorGroup;
use Stasis::Extension qw/span_sum/;

our @ISA = "Stasis::Page";

sub page {
    my $self = shift;
    
    my $PAGE;
    my $XML;
    
    my $grouper = $self->{grouper};
    my $pm = $self->{pm};
    
    ############################
    # RAID DURATION / RAID DPS #
    ############################
    
    # Determine start time and end times (earliest/latest presence)
    my ($raidStart, $raidEnd, $raidPresence) = $self->{ext}{Presence}->presence;
    
    # Figure out pet owners.
    my %powner;
    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        if( $ractor->{pets} ) {
            foreach my $p (@{$ractor->{pets}}) {
                $powner{ $p } = $kactor;
            }
        }
    }
    
    # Calculate raid DPS
    # Also get a list of total damage by raid member (on the side)
    my %raiderSpans;
    my %raiderDamage;
    my %raiderDPS;
    my %raiderIncoming;
    my $raidDamage = 0;
    
    my @raiders = map { $self->{raid}{$_}{class} ? ( $_ ) : () } keys %{$self->{raid}};
    
    ####################
    # ACTIVITY and DPS #
    ####################
    
    # DPS activity per raider
    my $actOut = $self->{ext}{Activity}->sum(
        actor => \@raiders,
        -target => \@raiders,
        expand => [ "actor" ],
    );
    
    ######################
    # DAMAGE AND HEALING #
    ######################
    
    # Damage to mobs by raiders and their pets
    my $deOut = $self->{ext}{Damage}->sum( 
        actor => \@raiders, 
        -target => \@raiders, 
        expand => [ "actor" ], 
        fields => [ qw/hitTotal critTotal tickTotal/ ]
    );
    
    $_->{total} = $self->_addHCT( $_, "Total" ) foreach ( values %$deOut );
    
    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        # Only show raiders
        next unless $ractor->{class} && $self->{ext}{Presence}->presence($kactor);
        
        my $raider = $ractor->{class} eq "Pet" ? $powner{ $kactor } : $kactor;
        $raiderDamage{$raider} ||= 0;
        $raiderIncoming{$raider} ||= 0;
        
        $raiderDamage{$raider} += $deOut->{$kactor}{total} || 0 if $deOut->{$kactor};
        push @{$raiderSpans{$raider}}, @{$actOut->{$kactor}{spans}} if $actOut->{$kactor} && $actOut->{$kactor}{spans};
    }
    
    foreach (values %raiderDamage) {
        $raidDamage += $_;
    }
    
    #Prepare damageAtTime data if we are making a plot
    my $damageAtTime;
    my $damageAtTimeAcc; #ref to accumulated data
    if ($self->{plot}) { #Use damageAtTime
        $damageAtTime = $self->{ext}{Damage}->sum(
            actor => \@raiders, 
            -target => \@raiders, 
            expand => [ "actor" ], 
            fields => [ "damageAtTime" ]
        );
        $damageAtTimeAcc=$self->_accumulateAtTime("damageAtTime",$damageAtTime);
    }

    # Calculate incoming damage
    my $raidInDamage = 0;
    my $deInAll = $self->{ext}{Damage}->sum( 
        target => \@raiders, 
        expand => [ "target" ], 
        fields => [ qw/hitTotal critTotal tickTotal/ ]
    );
    
    $_->{total} = $self->_addHCT( $_, "Total" ) foreach ( values %$deInAll );

    #Prepare dinAtTime data if we are making a plot
    my $dinAtTime;
    my $dinAtTimeAcc; #ref to accumulated data
    if ($self->{plot}) { #Use dinAtTime
        $dinAtTime = $self->{ext}{Damage}->sum(
            target => \@raiders, 
            expand => [ "target" ], 
            fields => [ "damageAtTime" ]
        );
        $dinAtTimeAcc=$self->_accumulateAtTime("damageAtTime",$dinAtTime);
    }
    
    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        # Only show raiders
        next if !$ractor->{class} || $ractor->{class} eq "Pet" || !$self->{ext}{Presence}->presence($kactor);
        
        $raiderIncoming{$kactor} += $deInAll->{$kactor}{total} || 0 if $deInAll->{$kactor};
        $raidInDamage += $deInAll->{$kactor}{total} || 0 if $deInAll->{$kactor};
    }

	# Calculate death count
	my %deathCount;
    foreach my $deathevent (keys %{$self->{ext}{Death}{actors}}) {
        if ($self->{raid}{$deathevent} && 
            $self->{raid}{$deathevent}{class} &&
            $self->{raid}{$deathevent}{class} ne "Pet") {
				$deathCount{$deathevent} = @{$self->{ext}{Death}{actors}{$deathevent}};
        }
    }
    
    # Calculate raid healing
    # Also get a list of total healing and effectiving healing by raid member (on the side)
    my %raiderHealing;
    my %raiderHealingTotal;
    my $raidHealing = 0;
    my $raidHealingTotal = 0;
    
    # Friendly healing by raiders and their pets
    my $heOutFriendly = $self->{ext}{Healing}->sum( 
        actor => \@raiders, 
        target => \@raiders, 
        expand => [ "actor" ], 
        fields => [ qw/hitEffective critEffective tickEffective hitTotal critTotal tickTotal/ ]
    );
    
    $_->{total} = $self->_addHCT( $_, "Total" ) foreach ( values %$heOutFriendly );
    $_->{effective} = $self->_addHCT( $_, "Effective" ) foreach ( values %$heOutFriendly );

    #Prepare healingAtTime data if we are making a plot
    my $healingAtTime;
    my $healingAtTimeAcc; #ref to accumulated data
    if ($self->{plot}) { #Use healingAtTime
        $healingAtTime = $self->{ext}{Healing}->sum(
            actor => \@raiders, 
            target => \@raiders, 
            expand => [ "actor" ], 
            fields => [ "healingAtTime" ]
        );
        $healingAtTimeAcc=$self->_accumulateAtTime("healingAtTime",$healingAtTime);
    }
    
    while( my ($kactor, $ractor) = each (%{$self->{raid}}) ) {
        # Only show raiders
        next unless $ractor->{class} && $self->{ext}{Presence}->presence($kactor);
        
        my $raider = $ractor->{class} eq "Pet" ? $powner{ $kactor } : $kactor;
        $raiderHealing{$raider} ||= 0;
        $raiderHealingTotal{$raider} ||= 0;
        
        $raiderHealing{$raider} += $heOutFriendly->{$kactor}{effective} || 0 if $heOutFriendly->{$kactor};
        $raiderHealingTotal{$raider} += $heOutFriendly->{$kactor}{total} || 0 if $heOutFriendly->{$kactor};
        
		
        $raidHealing += $heOutFriendly->{$kactor}{effective} || 0;
        $raidHealingTotal += $heOutFriendly->{$kactor}{total} || 0;
		
    }
    
    ############
    # RAID DPS #
    ############
    
    my $raidDPS = $raidPresence && ($raidDamage / $raidPresence);
    
    ####################
    # PRINT TOP HEADER #
    ####################
    
    $PAGE .= $pm->pageHeader($self->{name}, "");
    $PAGE .= $pm->statHeader($self->{name}, "", $raidStart);
    
    $PAGE .= $pm->vertBox( "Raid summary",
        "Duration"   => sprintf( "%dm%02ds", $raidPresence/60, $raidPresence%60 ),
        "Damage out" => sprintf( "%d", $raidDamage || 0 ),
        "Damage in" => sprintf( "%d", $raidInDamage || 0 ),
        "Damage Healed" => sprintf( "%d", $raidHealing|| 0 ),
        "DPS"        => sprintf( "%d", $raidDPS || 0 ),
        "Members"    => scalar keys %raiderDamage,
    );
    
    ############
    # TAB LIST #
    ############
    
    my @deathlist;

    foreach my $deathevent (keys %{$self->{ext}{Death}{actors}}) {
        if ($self->{raid}{$deathevent} && 
            $self->{raid}{$deathevent}{class} &&
            $self->{raid}{$deathevent}{class} ne "Pet") {
                push @deathlist, @{$self->{ext}{Death}{actors}{$deathevent}};
        }
    }

    @deathlist = sort { $a->{'t'} <=> $b->{'t'} } @deathlist;
    
    my @tabs = ( "Damage Out", "DPS Out", "Damage In", "Healing", "Raid & Mobs", "Deaths"); 
    if ($self->{plot}) {push @tabs, "Plot";}
    $PAGE .= "<br />" . $pm->tabBar(@tabs);
    
    ################
    # DAMAGE CHART #
    ################
    
    my @damageHeader = (
            "Player",
            "R-Presence",
            "R-Activity",
            "R-Pres. DPS",
            "R-Act. DPS",
            "R-Dam. Out",
            "R-%",
            " ",
        );

    # Damage Out, then DPS
    my @damagesort;
    my ($DAMTYPE_OUT, $DAMTYPE_DPS) = (1,2);
    foreach my $damtype ($DAMTYPE_OUT, $DAMTYPE_DPS) {

	$PAGE .= $pm->tabStart((($damtype == $DAMTYPE_OUT)?"Damage Out":"DPS Out"));
	$PAGE .= $pm->tableStart();
	$PAGE .= $pm->tableHeader((($damtype == $DAMTYPE_OUT)?"Damage Out":"DPS Out"), @damageHeader);
    
	if ($damtype == $DAMTYPE_OUT) {
	    @damagesort = sort {
		$raiderDamage{$b} <=> $raiderDamage{$a} || $a cmp $b
		} keys %raiderDamage;
	} else {
	    @damagesort = sort {
		$raiderDPS{$b} <=> $raiderDPS{$a} || $a cmp $b
		} keys %raiderDPS;
	}
    
	my $mostdmg = keys %raiderDamage && $raiderDamage{ $damagesort[0] };
	my $mostdps = keys %raiderDPS && $raiderDPS{ $damagesort[0] };
	
	foreach my $actor (@damagesort) {
	    my $ptime = $self->{ext}{Presence}->presence($actor);

	    my $dpsTime = exists $raiderSpans{$actor} && span_sum( $raiderSpans{$actor} );
	    $raiderDPS{$actor} = $raiderDamage{$actor} && $dpsTime && ($raiderDamage{$actor} / $dpsTime);
        
	    my ($perc, $chart);
	    if ($damtype == $DAMTYPE_OUT) {
		$perc = $raiderDamage{$actor} && $raidDamage && sprintf( "%d%%", ceil($raiderDamage{$actor} / $raidDamage * 100));
		$chart = $mostdmg && sprintf( "%d", ceil($raiderDamage{$actor} / $mostdmg * 100) );

	    } else {
		$perc = $raiderDPS{$actor} && $raidDPS && ceil($raiderDPS{$actor} / $raidDPS * 100);
		$chart = $mostdps && sprintf( "%d", ceil($raiderDPS{$actor} / $mostdps * 100) );
	    }

	    $PAGE .= $pm->tableRow( 
				    header => \@damageHeader,
				    data => {
					"Player" => $pm->actorLink( $actor ),
					"R-Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
					"R-%" => $perc,
					"R-Dam. Out" => $raiderDamage{$actor},
					" " => $chart,
					"R-Pres. DPS" => $raiderDamage{$actor} && $dpsTime && $ptime && sprintf( "%d", $raiderDamage{$actor} / $ptime ),
					"R-Act. DPS" => $raiderDamage{$actor} && $dpsTime && sprintf( "%d", $raiderDamage{$actor} / $dpsTime ),
					"R-Activity" => $dpsTime && $ptime && sprintf( "%0.1f%%", $dpsTime / $ptime * 100 ),
				    },
				    type => "",
				    );
	}
    
	$PAGE .= $pm->tableEnd;
	$PAGE .= $pm->tabEnd;
    }

    #########################
    # DAMAGE INCOMING CHART #
    #########################
    
    my @damageInHeader = (
            "Player",
            "R-Presence",
            "",
            "R-Deaths",
            "",
            "R-Dam. In",
            "",
            "R-DinPS",
            "R-%",
            " ",
        );
    
    $PAGE .= $pm->tabStart("Damage In");
    $PAGE .= $pm->tableStart();
    $PAGE .= $pm->tableHeader("Damage In", @damageInHeader);
    
    my @damageinsort = sort {
        $raiderIncoming{$b} <=> $raiderIncoming{$a} || $a cmp $b
    } keys %raiderIncoming;
    
    my $mostindmg = keys %raiderIncoming && $raiderIncoming{ $damageinsort[0] };
    
    foreach my $actor (@damageinsort) {
        my $ptime = $self->{ext}{Presence}->presence($actor);
        
        $PAGE .= $pm->tableRow( 
            header => \@damageInHeader,
            data => {
                "Player" => $pm->actorLink( $actor ),
                "R-DinPS" => $raiderIncoming{$actor} && $ptime && sprintf( "%d", $raiderIncoming{$actor} / $ptime ),
                "R-Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-%" => $raiderIncoming{$actor} && $raidInDamage && sprintf( "%d%%", ceil($raiderIncoming{$actor} / $raidInDamage * 100) ),
                "R-Dam. In" => $raiderIncoming{$actor},
                "R-Deaths" => $deathCount{$actor} || " 0",
                " " => $mostindmg && sprintf( "%d", ceil($raiderIncoming{$actor} / $mostindmg * 100) ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    #################
    # HEALING CHART #
    #################
    
    my @healingHeader = (
            "Player",
            "R-Presence",
            "",
            "R-Overheal",
            "",
            "R-Eff. Heal",
            "",
            "R-HPS",
            "R-%",
            " ",
        );
        
    $PAGE .= $pm->tabStart("Healing");
    $PAGE .= $pm->tableStart();
    $PAGE .= $pm->tableHeader("Healing", @healingHeader);    
    
    my @healsort = sort {
        $raiderHealing{$b} <=> $raiderHealing{$a} || $a cmp $b
    } keys %raiderHealing;
    
    my $mostheal = keys %raiderHealing && $raiderHealing{ $healsort[0] };
    
    foreach my $actor (@healsort) {
        my $ptime = $self->{ext}{Presence}->presence($actor);
        
        $PAGE .= $pm->tableRow( 
            header => \@healingHeader,
            data => {
                "Player" => $pm->actorLink( $actor ),
                "R-Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Eff. Heal" => $raiderHealing{$actor},
                "R-HPS" => $raiderHealing{$actor} && $ptime && sprintf( "%d", $raiderHealing{$actor} / $ptime ),
                "R-%" => $raiderHealing{$actor} && $raidHealing && sprintf( "%d%%", ceil($raiderHealing{$actor} / $raidHealing * 100) ),
                " " => $mostheal && $raiderHealing{$actor} && sprintf( "%d", ceil($raiderHealing{$actor} / $mostheal * 100) ),
                "R-Overheal" => $raiderHealingTotal{$actor} && $raiderHealing{$actor} && sprintf( "%0.1f%%", ($raiderHealingTotal{$actor}-$raiderHealing{$actor}) / $raiderHealingTotal{$actor} * 100 ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    ####################
    # RAID & MOBS LIST #
    ####################
    
    my @actorHeader = (
        "Actor",
        "Class",
        "Presence",
        "R-Presence %",
    );
        
    $PAGE .= $pm->tabStart("Raid & Mobs");
    $PAGE .= $pm->tableStart();
    
    {
        my @actorsort = sort {
            $self->{index}->actorname($a) cmp $self->{index}->actorname($b)
        } keys %{$self->{ext}{Presence}{actors}};
        
        $PAGE .= "";
        $PAGE .= $pm->tableHeader("Raid &amp; Mobs", @actorHeader);

        my @rows;

        foreach my $actor (@actorsort) {
            my ($pstart, $pend, $ptime) = $self->{ext}{Presence}->presence($actor);
            
            my $group = $grouper->group($actor);
            if( $group ) {
                # See if this should be added to an existing row.
                
                my $found;
                foreach my $row (@rows) {
                    if( $row->{key} eq $group->{members}->[0] ) {
                        # It exists. Add this data to the existing master row.
                        $row->{row}{start} = $pstart if( $row->{row}{start} > $pstart );
                        $row->{row}{end} = $pstart if( $row->{row}{end} < $pend );
                        
                        $found = 1;
                        last;
                    }
                }
                
                if( !$found ) {
                    # Create the row.
                    push @rows, {
                        key => $group->{members}->[0],
                        row => {
                            start => $pstart,
                            end => $pend,
                        },
                    }
                }
            } else {
                # Create the row.
                push @rows, {
                    key => $actor,
                    row => {
                        start => $pstart,
                        end => $pend,
                    },
                }
            }
        }
        
        foreach my $row (@rows) {
            # Master row
            my $class = $self->{raid}{$row->{key}}{class} || "Mob";
            my $owner;
            
            if( $class eq "Pet" ) {
                foreach (keys %{$self->{raid}}) {
                    if( grep $_ eq $row->{key}, @{$self->{raid}{$_}{pets}}) {
                        $owner = $_;
                        last;
                    }
                }
            }
            
            my $group = $grouper->group($row->{key});
            my ($pstart, $pend, $ptime) = $self->{ext}{Presence}->presence( $group ? @{$group->{members}} : $row->{key} );
            
            $PAGE .= $pm->tableRow( 
                header => \@actorHeader,
                data => {
                    "Actor" => $pm->actorLink( $row->{key} ),
                    "Class" => $class . ($owner ? " (" . $pm->actorLink($owner) . ")" : "" ),
                    "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                    "R-Presence %" => $raidPresence && sprintf( "%d%%", ceil($ptime/$raidPresence*100) ),
                },
                type => "",
            );
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    ##########
    # DEATHS #
    ##########

    $PAGE .= "";

    my @deathHeader = (
        "Death",
        "Time",
        "R-Health",
        "Event",
    );
    
    $PAGE .= $pm->tabStart("Deaths");
    $PAGE .= $pm->tableStart();
    
    my %dnum;
    if( scalar @deathlist ) {
        $PAGE .= $pm->tableHeader("Deaths", @deathHeader);
        foreach my $death (@deathlist) {
            my $id = lc $death->{actor};
            $id = $self->{pm}->tameText($id);
            
            # Get the last line of the autopsy.
            my $lastline = $death->{autopsy}->[-1];
            my $text = $lastline ? $lastline->{event}->toString( 
                sub { $self->{pm}->actorLink( $_[0], 1 ) }, 
                sub { $self->{pm}->spellLink( $_[0] ) } 
            ) : "";
            
            my $t = $death->{t} - $raidStart;
            $PAGE .= $pm->tableRow(
                header => \@deathHeader,
                data => {
                    "Death" => $pm->actorLink( $death->{actor},  $self->{index}->actorname($death->{actor}), $self->{raid}{$death->{actor}}{class} ),
                    "Time" => $death->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                    "R-Health" => $lastline->{hp} || "",
                    "Event" => $text,
                },
                type => "master",
                url => sprintf( "death_%s_%d.json", $id, ++$dnum{ $death->{actor} } ),
            );
            
            # Print subsequent rows.
            foreach my $line (@{$death->{autopsy}}) {
                $PAGE .= $pm->tableRow(
                    header => \@deathHeader,
                    data => {},
                    type => "slave",
                );
            }
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;

    #####################
    # FLOT PLOTS        #
    #####################
    if ($self->{plot}) { 
        #Prepare the data
        my @dpstimestamps=keys %$damageAtTimeAcc;
        my @healingtimestamps=keys %$healingAtTimeAcc;
        my @dintimestamps=keys %$dinAtTimeAcc;
        my @timestamps=sort (@dpstimestamps,@healingtimestamps,@dintimestamps);
        my $mintime=$timestamps[0]; my $maxtime=$timestamps[-1];
	    
        my $dpsString="[";
        my $healString="[";
        my $dinString="[";
        
        #These three hold the last value we used so we can skip repeat zero values to keep page sizes down in long parses
        #The time ones are used to make sure we don't repeat a write when we have to write out the entry before
        my $lastDout=0; my $lastDoutTime=0;
        my $lastHeal=0; my $lastHealTime=0;
        my $lastDin=0; my $lastDinTime=0;
        
        for (my $i=$mintime; $i<=$maxtime; $i++) {
	        if (exists $damageAtTimeAcc->{$i}) {
	    	    if (!$lastDout && $i-1 != $lastDoutTime) { $dpsString.="[". ($i-1) ."000,0],"; }
	    	    $dpsString.="[$i"."000,".$damageAtTimeAcc->{$i}."],";
	    	    $lastDout = $damageAtTimeAcc->{$i}; $lastDoutTime=$i;
	        } elsif ($lastDout) { $dpsString.="[". $i ."000,0],"; $lastDout=0; $lastDoutTime=$i;}
	        if (exists $healingAtTimeAcc->{$i}) {
	            if (!$lastHeal && $i-1 != $lastHealTime) { $healString.="[". ($i-1) ."000,0],"; }
	            $healString.="[$i"."000,".$healingAtTimeAcc->{$i}."],"; 
	            $lastHeal=$healingAtTimeAcc->{$i}; $lastHealTime=$i;
	        } elsif ($lastHeal) { $healString.="[". $i ."000,0],"; $lastHeal=0; $lastHealTime=$i;}
	        if (exists $dinAtTimeAcc->{$i}) {
	            if (!$lastDin && $i-1 != $lastDinTime) { $dinString.="[". ($i-1) ."000,0],"; }
	            $dinString.="[$i"."000,".$dinAtTimeAcc->{$i}."],";
	            $lastDin = $dinAtTimeAcc->{$i}; $lastDinTime=$i;
	        } elsif ($lastDin) { $dinString.="[". $i ."000,0],"; $lastDin=0; $lastDinTime=$i;}
        }
       $dpsString =~ s/,$/]/; #closes the array
	   $healString =~ s/,$/]/; #closes the array
       $dinString =~ s/,$/]/; #closes the array
	    
	    #Prepare the page
	    my @plotHeader = ( "Damage out (red), Healing (blue), Damage in (black)");
		
	    $PAGE .= $pm->tabStart("Plot");
        $PAGE .= $pm->tableStart();
        $PAGE .= $pm->tableHeader("Plot", @plotHeader);
        $PAGE .= $pm->tableEnd;

        #Insert flotplot
        #this is dummy code
        $PAGE .= <<END;
<div id="mainplot" style="width:700px;height:300px;"></div>
<div id="miniplot" style="width:700px;height:100px;"></div>
<script id="source" language="javascript" type="text/javascript">
\$(function () {
    var dps = $dpsString;
    var heal = $healString;
    var din = $dinString;
    var options = {
        legend: { show: false },
        series: {
            lines: { show: true },
            points: { show: false }
        },
        xaxis: { mode: "time", ticks: 6 },
        yaxis: { ticks: 10 },
        selection: { mode: "x" }
    };
    
    var mainplot = \$.plot(\$("#mainplot"), [ {data:dps,color:"rgb(255,0,0)"}, {data:heal,color:"rgb(0,0,255)"}, {data:din,color:"rgb(0,0,0)"} ], options);

    var miniplot = \$.plot(\$("#miniplot"), [ {data:dps,color:"rgb(255,0,0)"}, {data:heal,color:"rgb(0,0,255)"}, {data:din,color:"rgb(0,0,0)"} ], {
        legend: { show: false },
        series: {
            lines: { show: true, lineWidth: 1 },
            shadowSize: 0
        },
        xaxis: { ticks: 6, mode: "time" },
        yaxis: { ticks: 2 },
        grid: { color: "#999" },
        selection: { mode: "x" }
    });
    
    \$("#mainplot").bind("plotselected", function (event, ranges) {
        // clamp the zooming to prevent eternal zoom
        if (ranges.xaxis.to - ranges.xaxis.from < 0.00001)
            ranges.xaxis.to = ranges.xaxis.from + 0.00001;
        
        // do the zooming
        mainplot = \$.plot(\$("#mainplot"),[ {data:dps,color:"rgb(255,0,0)"}, {data:heal,color:"rgb(0,0,255)"}, {data:din,color:"rgb(0,0,0)"} ],
                      \$.extend(true, {}, options, {
                          xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                      }));
        
        // don't fire event on the overview to prevent eternal loop
        miniplot.setSelection(ranges, true);
    });
    \$("#miniplot").bind("plotselected", function (event, ranges) {
        mainplot.setSelection(ranges);
    });
});
</script>        

END
        $PAGE .= $pm->tabEnd;
        
	}
    #####################
    # PRINT HTML FOOTER #
    #####################
    if ($self->{plot}) {
        $PAGE .= $pm->jsTab("Plot");
    } else {$PAGE .= $pm->jsTab("Damage Out");} #This is necessary as flot hates being hidden
    $PAGE .= $pm->tabBarEnd;
    $PAGE .= $pm->pageFooter;
    
    if( wantarray ) {
        #########################
        # PRINT OPENING XML TAG #
        #########################
        
 	$XML .= sprintf( '  <raid dpstime="%d" start="%s" dps="%d" comment="%s" lg="%d" dmg="%d" dir="%s" zone="%s" heroic="%d">' . "\n",            100,
            $raidStart*1000,
            $raidDPS,
            $self->{name},
            $raidPresence*60000,
            $raidDamage,
            $self->{dirname},
            Stasis::LogSplit->zone( $self->{short} ) || "",
			$self->{heroic} || 0,
        );

        #########################
        # PRINT PLAYER XML KEYS #
        #########################

        my %xml_classmap = (
            "Warrior" => "war",
            "Druid" => "drd",
            "Warlock" => "wrl",
            "Shaman" => "sha",
            "Paladin" => "pal",
            "Priest" => "pri",
            "Rogue" => "rog",
            "Mage" => "mag",
            "Hunter" => "hnt",
            "Death Knight" => "dk",
        );

        foreach my $actor (@damagesort) {
            my $ptime = $self->{ext}{Presence}->presence($actor);
            my $dpsTime = exists $raiderSpans{$actor} && span_sum( $raiderSpans{$actor} );
            
            # Count decurses.
            my $decurse = 0;
            if( exists $self->{ext}{Dispel}{actors}{$actor} ) {
                while( my ($kspell, $vspell) = each(%{ $self->{ext}{Dispel}{actors}{$actor} } ) ) {
                    while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                        while( my ($kextraspell, $vextraspell) = each (%$vtarget) ) {
                            # Add the row.
                            $decurse += $vextraspell->{count} - ($vextraspell->{resist}||0);
                        }
                    }
                }
            }

            my %xml_keys = (
                name => HTML::Entities::encode_entities_numeric( $self->{index}->actorname($actor) ) || "Unknown",
                classe => $xml_classmap{ $self->{raid}{$actor}{class} } || "war",
                dps => $dpsTime && ceil( $raiderDamage{$actor} / $dpsTime ) || 0,
                dpstime => $raidPresence && $ptime &&  $ptime/$raidPresence  * 100 || 0,
                dmgout => $raiderDamage{$actor} && $raidDamage && $raiderDamage{$actor} || 0,
                dmgin => $raiderIncoming{$actor}|| 0,
                heal => $raiderHealing{$actor}  || 0,
                hps => $ptime && ceil( $raiderHealing{$actor} / $ptime ) || 0,
                ovh => $raiderHealing{$actor} && $raiderHealingTotal{$actor} && ceil( ($raiderHealingTotal{$actor} - $raiderHealing{$actor}) / $raiderHealingTotal{$actor} * 100 ) || 0,
                death => $deathCount{$actor} || 0,
                decurse => $decurse,
                
                # Ignored values
                pres => 100,
            );

            $XML .= sprintf "    <player %s />\n", join " ", map { sprintf "%s=\"%s\"", $_, $xml_keys{$_} } (keys %xml_keys);
        }

        ####################
        # PRINT XML FOOTER #
        ####################

        $XML .= "  </raid>\n";
    }
    
    return wantarray ? ($XML, $PAGE) : $PAGE;
}

1;
