PLAN
====
* flytt Model::Note->from_alsaevent ut til f.eks Model::Util og endre til å returnere MIDI::Score note
* od -A x -t x1z -v midi/T6ng-000.MID
* * 90 = note_on, se MIDI/Event
* script Enkel avspiller timidity for notes filer

* Prøv først MIDI::ALSA for å lese input
* Se https://mojolicious.io/blog/2017/12/21/day-21-virtually-a-lumberjack/index.html og https://perldoc.perl.org/IO/Handle.html (->fdopen)
* først manuelt

* Ut vides med en mojo greie som skriver til skjerm automatisk

UTGÅR
=====
* [fungerte ikke lyttet kun til /dev/music må lytte til /dev/snd/...] Midi::Music daemon som automatisk lager en midi fil når det er stille i 3 sekunder



* Copy https://gist.github.com/augensalat/3699443
