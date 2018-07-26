PLAN
===
* Neste gang:
* Jobb med register_event og fiks feil.
* Test ut sak-programmet https://trello.com/b/LPO2GFPO Du har allerede en bruker.
* Skill ut MIDI::ALSA til Model::Loop::ALSA (Model::Loop::WebUSB kommer)
* Se på websocket støtten her: Writing websocket chat using Mojolicious Lite · kraih_mojo Wiki · GitHub.html
** https://github.com/kraih/mojo/wiki/Writing-websocket-chat-using-Mojolicious-Lite
** https://developers.google.com/web/updates/2016/03/access-usb-devices-on-the-web
** les usb fra web(skriv dump til web)
** eksprimenter med grafiske noter

* Finn et bedre navn på hoved script. (piano_trainer.pl)
* mulig gjør commit fra fredriks maskin (Opprett bruker på hans maskin)
* Kalkuler en låt vanskelighetsgrad (denominator=8 * antall noter?)
* Skriv en bedre read me.
* Lag oppstart med navn
* Print tips, mål om det spilles stakato eller ikke.
* Lag ranking pi
* Legg inn poc tester


DONE
====
* Endre score. Teller mindre om man spiller stakato og mindre straff for å spille feil
* Begynn med web støtte
** splitt record-midi-music.pl.
*** lag ny lib: Model::Controller alle do_*,init,alle has, alsa_read, pn,guessed_blueprint,local_dir,...
*** Beholdes i record-midi-music.pl: main, stdin_read, print_help
* Renskriv kommentarer script
* midi2notes.pl fikser dette: Har Kunne lagre midi og trekke ut noter fra midi som en test.
* styrke 0 = note_off
* play må kunne spille .midi filer også.
* script for renskrivning av låter clean....txt.pl
* Øke til to noter for å identifisere en fasit
* Tippe toneart
* Lag database register over låter for å tippe låt automatisk
	(prøv å lag programmet uavhenig av tastatur)
* Kunne bytte toneart etc.
* Finn riktig låt automatisk
* Trigge enter hvis stille i 2 sek.
* Print score til slutt etter note utskrift
* Søk i gjennom blueprints hvis ikke fil finnes hvor angitt for fasit fil
* Lag liste opsjonen
* * 90 = note_on, se MIDI/Event
* script Enkel avspiller timidity for notes filer
* først manuelt
* Ut vides med en mojo greie som skriver til skjerm automatisk
* Se https://mojolicious.io/blog/2017/12/21/day-21-virtually-a-lumberjack/index.html og https://perldoc.perl.org/IO/Handle.html (->fdopen)
* Prøv først MIDI::ALSA for å lese input
* od -A x -t x1z -v midi/T6ng-000.MID
* flytt Model::Note->from_alsaevent ut til f.eks Model::Util og endre til å returnere MIDI::Score note

UTGÅR
=====
* Feil første note ignoreres
* [fungerte ikke lyttet kun til /dev/music må lytte til /dev/snd/...] Midi::Music daemon som automatisk lager en midi fil når det er stille i 3 sekunder
* Copy https://gist.github.com/augensalat/3699443
* tunnelbroker for å nå
** https://www.linode.com/docs/networking/set-up-an-ipv6-tunnel-on-your-linode/
** Lag fil:/etc/sysconfig/network-scripts/ifcfg-he-ipv6
** Enten slik: https://gist.github.com/briancline/9360785
** Eller: https://www.linode.com/docs/networking/set-up-an-ipv6-tunnel-on-your-linode/#centos-7-and-fedora-22
