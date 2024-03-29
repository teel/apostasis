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

sub array_smooth {
    #smooth an array using a moving average, $smooth parameter is how many above and below central value
    #so for example $smooth=1 is a window of width 3
    my ($aref,$smooth) = @_;
    my @array=@$aref;
    my @output;
    my @temp;
    my $low; my $high; my $length;
    
    for (my $i=0; $i<$#array; $i++) {
        $length=0;
        my $low = $i-$smooth < 0 ? 0 : $i-$smooth;
        my $high = $i+$smooth > $#array-1 ? $#array-1 : $i+$smooth;
        foreach (@array[$low .. $high]) {$temp[$i] += $_ ; $length++;}
        $temp[$i] /= $length;
    }
    
    for (my $i=0; $i<$#temp; $i+=$smooth) {
        push @output, $temp[$i];
    }
    return \@output;
}

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
    my @raidersNoPets;
    foreach (@raiders) {
        unless ($self->{raid}{$_}{class} eq 'Pet') {push @raidersNoPets,$_;}
    }
    
    ####################
    # ACTIVITY and DPS #
    ####################
    
    # DPS activity per raider
    my $actOut = $self->{ext}{Activity}->sum(
        actor => \@raiders,
        -target => \@raiders,
        expand => [ "actor" ],
    );
    
    #############################
    # AURAS - HEROISM/BLOODLUST #
    #############################
    
    #used in plots
    my (@herostart,@heroend);
    my $heroism = $self->{ext}{Aura}->sum(
        actor => \@raiders,
        target => \@raidersNoPets,
        spell => [32182,2825],
        expand => [ "spans" ],
    ); #showing my Alliance bias in names, I know

    if (defined ($heroism->{spans})) {
        foreach (@{$heroism->{spans}}) {
            my ($htmps,$htmpe) = unpack "dd",$_;
            if ($htmpe-$htmps > 45) {$htmpe=$htmps+45;}
            $htmps*=1000; $htmpe*=1000;
            push @herostart, $htmps; push @heroend, $htmpe;
        }
    }

    ######################
    # DAMAGE AND HEALING #
    ######################
    
    # Damage to mobs by raiders and their pets
    my $deOut = $self->{ext}{Damage}->sum( 
        actor => \@raiders, 
        -target => \@raiders,
        expand => [ "actor" ], 
        fields => [ qw/hitTotal critTotal tickTotal damageAtTime/ ]
    );

    $_->{total} = $self->_addHCT( $_, "Total" ) foreach ( values %$deOut );

    my $damageAtTimeAcc; #ref to accumulated data

    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        # Only show raiders
        next unless $ractor->{class} && $self->{ext}{Presence}->presence($kactor);
        
        my $raider = $ractor->{class} eq "Pet" ? $powner{ $kactor } : $kactor;
        $raiderDamage{$raider} ||= 0;
        $raiderIncoming{$raider} ||= 0;
        
        $raiderDamage{$raider} += $deOut->{$kactor}{total} || 0 if $deOut->{$kactor};
        push @{$raiderSpans{$raider}}, @{$actOut->{$kactor}{spans}} if $actOut->{$kactor} && $actOut->{$kactor}{spans};
        if ($self->{plot}) { foreach (keys %{$deOut->{$kactor}{damageAtTime}}) { $damageAtTimeAcc->{$_} += ${$deOut->{$kactor}{damageAtTime}}{$_};} }
    }
    foreach (values %raiderDamage) {
        $raidDamage += $_;
    }
    


    # Calculate incoming damage
    my $raidInDamage = 0;
    my $deInAll = $self->{ext}{Damage}->sum( 
        target => \@raiders, 
        expand => [ "target" ], 
        fields => [ qw/hitTotal critTotal tickTotal damageAtTime/ ]
    );
    
    $_->{total} = $self->_addHCT( $_, "Total" ) foreach ( values %$deInAll );

    my $dinAtTimeAcc; #ref to accumulated data

    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        # Only show raiders
        next if !$ractor->{class} || $ractor->{class} eq "Pet" || !$self->{ext}{Presence}->presence($kactor);
        
        $raiderIncoming{$kactor} += $deInAll->{$kactor}{total} || 0 if $deInAll->{$kactor};
        $raidInDamage += $deInAll->{$kactor}{total} || 0 if $deInAll->{$kactor};
        if ($self->{plot}) { foreach (keys %{$deInAll->{$kactor}{damageAtTime}}) { $dinAtTimeAcc->{$_} += ${$deInAll->{$kactor}{damageAtTime}}{$_};} }
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
        #target => \@raiders, 
        expand => [ "actor" ], 
        fields => [ qw/hitEffective critEffective tickEffective hitTotal critTotal tickTotal healingAtTime/ ]
    );
    
    $_->{total} = $self->_addHCT( $_, "Total" ) foreach ( values %$heOutFriendly );
    $_->{effective} = $self->_addHCT( $_, "Effective" ) foreach ( values %$heOutFriendly );

    my $healingAtTimeAcc; #ref to accumulated data
    
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
        if ($self->{plot}) { foreach (keys %{$heOutFriendly->{$kactor}{healingAtTime}}) { $healingAtTimeAcc->{$_} += ${$heOutFriendly->{$kactor}{healingAtTime}}{$_};} }
        
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
        
        #Find the timezone for the plot
        my $tZOffset = $self->timeZoneOffset($mintime);
        
        #First check if we need to smooth at all
        my $smooth;
        my $maxNtimestamps = 1200; #20 minutes
        if ($maxtime-$mintime > $maxNtimestamps) { $smooth = int (0.5+($maxtime-$mintime)/(2*$maxNtimestamps));} else {$smooth = 0}
        
        #Arrange in arrays and smooth if needed
        my @damageAtTimeArr; my @healingAtTimeArr; my @dinAtTimeArr; my @timeArr;
        for (my $i=$mintime; $i<=$maxtime; $i++) {
            if (exists $damageAtTimeAcc->{$i}) {$damageAtTimeArr[$i-$mintime] = $damageAtTimeAcc->{$i}} else {$damageAtTimeArr[$i-$mintime] = 0}
            if (exists $healingAtTimeAcc->{$i}) {$healingAtTimeArr[$i-$mintime] = $healingAtTimeAcc->{$i}} else {$healingAtTimeArr[$i-$mintime] = 0}
            if (exists $dinAtTimeAcc->{$i}) {$dinAtTimeArr[$i-$mintime] = $dinAtTimeAcc->{$i}} else {$dinAtTimeArr[$i-$mintime] = 0}
            $timeArr[$i-$mintime]=$i+$tZOffset;
        }
        
        if ($smooth) {
            @damageAtTimeArr=@{array_smooth(\@damageAtTimeArr,$smooth)};
            @healingAtTimeArr=@{array_smooth(\@healingAtTimeArr,$smooth)};
            @dinAtTimeArr=@{array_smooth(\@dinAtTimeArr,$smooth)};
            @timeArr=@{array_smooth(\@timeArr,$smooth)};
        }
        
        #Now write the strings out
        
        my $dpsString="[";
        my $healString="[";
        my $dinString="[";
        #These three hold the last value we used so we can skip repeat zero values to keep page sizes down in long parses
        #The time ones are used to make sure we don't repeat a write when we have to write out the entry before
        my $lastDout=0; my $lastDoutTime=0;
        my $lastHeal=0; my $lastHealTime=0;
        my $lastDin=0; my $lastDinTime=0;
        
        for (my $i=0; $i<$#timeArr; $i++) {
            if ($damageAtTimeArr[$i]) {
                    if ($i-1 >=0 && (!$lastDout && $i-1 != $lastDoutTime)) { $dpsString.="[". $timeArr[$i-1]*1000 .",0],"; }
                    $dpsString.="[".$timeArr[$i]*1000 .",".$damageAtTimeArr[$i]."],";
                    $lastDout = $damageAtTimeArr[$i]; $lastDoutTime=$i;
            } elsif ($lastDout) { $dpsString.="[". $timeArr[$i]*1000 .",0],"; $lastDout=0; $lastDoutTime=$i;}
            if ($healingAtTimeArr[$i]) {
                if ($i-1 >= 0 && (!$lastHeal && $i-1 != $lastHealTime)) { $healString.="[". $timeArr[$i-1]*1000 .",0],"; }
                $healString.="[".$timeArr[$i]*1000 .",".$healingAtTimeArr[$i]."],"; 
                $lastHeal=$healingAtTimeArr[$i]; $lastHealTime=$i;
            } elsif ($lastHeal) { $healString.="[". $timeArr[$i]*1000 .",0],"; $lastHeal=0; $lastHealTime=$i;}
            if (exists $dinAtTimeArr[$i]) {
                if ($i-1 >= 0 && (!$lastDin && $i-1 != $lastDinTime)) { $dinString.="[". $timeArr[$i-1]*1000 .",0],"; }
                $dinString.="[".$timeArr[$i]*1000 .",".$dinAtTimeArr[$i]."],";
                $lastDin = $dinAtTimeArr[$i]; $lastDinTime=$i;
            } elsif ($lastDin) { $dinString.="[". $timeArr[$i]*1000 .",0],"; $lastDin=0; $lastDinTime=$i;}
        } 
       
        $dpsString =~ s/,$/]/; #closes the array
        $healString =~ s/,$/]/; #closes the array
        $dinString =~ s/,$/]/; #closes the array
        
        #Prepare heroism additional strings
        my $markString = "";
        if (defined($herostart[0]) or scalar @deathlist) {
            #we need to show heroism/bloodlust and/or deaths
            $markString = ", markings: [ \n";
        }

        if (defined($herostart[0])) {
            for (my $i=0; $i<$#herostart; $i++) {
                #need to figure out why sometimes the heroism ending isn't picked up
                #we can probably cope without though as long as enough people get it parsed correctly
                unless ($herostart[$i] == 0 or $heroend[$i] == 0) {
                    #fix for timezone then write out
                    $herostart[$i] += $tZOffset*1000; $heroend[$i] += $tZOffset*1000;
                    $markString .= "{ xaxis: { from: $herostart[$i], to: $heroend[$i] }, color: \"#e5e5ff\" },\n";
                } 
            }
        }
        
        #Prepare death data
        my @deathTimes; my @deathLinks;
        #including code for tooltip
        my $deathToolTip = <<ENDTOOLTIP;
    var toolTipPrev = null;
    function showTooltip(x, y, contents) {
        \$('<div id="tooltip">' + contents + '</div>').css( {
            position: 'absolute',
            display: 'none',
            top: y + 5,
            left: x + 5,
            border: '1px solid #fdd',
            padding: '2px',
            'background-color': '#fee',
            opacity: 0.80,
            'font-size': 'small'
        }).appendTo("body").fadeIn(200);
    }
ENDTOOLTIP
       #this will hold extra data to for the death tooltip
       my $deathLegendAddition="";        
        if ( scalar @deathlist ) {
            $deathToolTip .= "    var deathData = [";
            foreach my $death (@deathlist) {
                my $t = ($death->{t}+$tZOffset) * 1000;
                my $link = "Death: " . $pm->{index}->actorname($death->{actor});
                $markString .= "{ xaxis: { from: $t, to : $t }, color: \"#ffc5c5\" },\n";
                push @deathTimes, $t; push @deathLinks, $link;
                $deathToolTip .= "[$t,'$link'],";
            }
            $deathToolTip =~ s/,$/];\n/;
            $deathLegendAddition .= 
            "        for (j=0; j<deathData.length-1; ++j)\n".
            "            if (deathData[j][0] > pos.x)\n".
            "                break;\n".
            #find nearest of the two points
            "        if (j != 0 && Math.abs(deathData[j][0] - pos.x) > Math.abs(deathData[j-1][0] - pos.x)) --j;\n".
            #restrict tooltip firing to only if you're within 5 seconds of the death, and if we're not already showing it
            #it'd be nicer to scale this by zoom in the future
            "        if ((Math.abs(deathData[j][0] - pos.x) < 5000) && (toolTipPrev != j)) {\n".
            "            toolTipPrev = j;\n".
            "            \$(\"#tooltip\").remove();\n".
            "            showTooltip(pos.pageX, pos.pageY, deathData[j][1]);\n".
            "        } else { \$(\"#tooltip\").remove(); toolTipPrev = null;}\n";
            
        }

        if (defined($herostart[0]) or scalar @deathlist) {
            $markString .= " ] ";
        }


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
<div id="plothover"></div>
<script id="source" language="javascript" type="text/javascript">
\$(function () {
    var dps = $dpsString;
    var heal = $healString;
    var din = $dinString;

    var options = {
        series: {
            lines: { show: true },
            points: { show: false }
        },
        xaxis: { mode: "time", ticks: 6 },
        yaxis: { ticks: 10 },
        selection: { mode: "xy" },
        crosshair: {mode: "x" },
        grid: { hoverable: true, autoHighlight: false $markString}
    };
    
    var mainplot = \$.plot(\$("#mainplot"), [ {data:dps,color:"rgb(255,0,0)", label:"Dmg out = --------"}, {data:heal,color:"rgb(0,0,255)", label:"Healing = --------"}, {data:din,color:"rgb(0,0,0)", label:"Dmg in = --------"} ], options);
    var legends = \$("#mainplot .legendLabel");
    legends.each(function () {
        // fix the widths so they don't jump around
        \$(this).css('width', \$(this).width());
    });

    var updateLegendTimeout = null;
    var latestPosition = null;

$deathToolTip

    function updateLegend() {
        updateLegendTimeout = null;
        
        var pos = latestPosition;
        var axes = mainplot.getAxes();
        if (pos.x < axes.xaxis.min || pos.x > axes.xaxis.max ||
            pos.y < axes.yaxis.min || pos.y > axes.yaxis.max)
            return;

        var i, j, dataset = mainplot.getData();
        for (i = 0; i < dataset.length; ++i) {
            var series = dataset[i];

            // find the nearest points, x-wise
            for (j = 0; j < series.data.length; ++j)
                if (series.data[j][0] > pos.x)
                    break;
            
            // now interpolate
            var y, p1 = series.data[j - 1], p2 = series.data[j];
            if (p1 == null)
                y = p2[1];
            else if (p2 == null)
                y = p1[1];
            else
                y = p1[1] + (p2[1] - p1[1]) * (pos.x - p1[0]) / (p2[0] - p1[0]);
            legends.eq(i).text(series.label.replace(/=.*/, "= " + y.toFixed(0)));
        }
    }
    
    \$("#mainplot").bind("plothover",  function (event, pos, item) {
        latestPosition = pos;
        if (!updateLegendTimeout)
            updateLegendTimeout = setTimeout(updateLegend, 50);
$deathLegendAddition
    });

    var miniplot = \$.plot(\$("#miniplot"), [ {data:dps,color:"rgb(255,0,0)"}, {data:heal,color:"rgb(0,0,255)"}, {data:din,color:"rgb(0,0,0)"} ], {
        legend: { show: false },
        series: {
            lines: { show: true, lineWidth: 1 },
            shadowSize: 0
        },
        xaxis: { ticks: 6, mode: "time" },
        yaxis: { ticks: 2 },
        grid: { color: "#999" $markString},
        selection: { mode: "xy" }
    });
    
    \$("#mainplot").bind("plotselected", function (event, ranges) {
        // clamp the zooming to prevent eternal zoom
        if (ranges.xaxis.to - ranges.xaxis.from < 0.00001)
            ranges.xaxis.to = ranges.xaxis.from + 0.00001;
        if (ranges.yaxis.to - ranges.yaxis.from < 0.00001)
            ranges.yaxis.to = ranges.yaxis.from + 0.00001;
        // do the zooming
        mainplot = \$.plot(\$("#mainplot"),[ {data:dps,color:"rgb(255,0,0)", label:"Dmg out = -------"}, {data:heal,color:"rgb(0,0,255)", label:"Healing = -------"}, {data:din,color:"rgb(0,0,0)", label:"Dmg in = -------"} ],
                      \$.extend(true, {}, options, {
                          xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                          yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }
                      }));
        // reset legends
        legends = \$("#mainplot .legendLabel");
        legends.each(function () {
        // fix the widths so they don't jump around
        \$(this).css('width', \$(this).width());
    });
        // don't fire event on the overview to prevent eternal loop
        miniplot.setSelection(ranges, true);
    });
    \$("#miniplot").bind("plotselected", function (event, ranges) {
        mainplot.setSelection(ranges);
    });
    
});
</script>        

END
        if ($smooth) {$PAGE .= "<div>Smoothed with window of +- $smooth seconds.</div>\n";}
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
