PLAN
====
* Begynn med web støtte
** les usb fra web(skriv dump til web)
** eksprimenter med grafiske noter
* Finn et bedre navn på hoved script.
* mulig gjør commit fra fredriks maskin
* Kalkuler en låt vanskelighetsgrad
* Skriv en bedre read me.
* Lag oppstart med navn
* Renskriv kommentarer script
* Print tips, mål om det spilles stakato eller ikke.
* Lag ranking

DONE
====
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
