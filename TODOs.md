# TODOs, Known problems, ideas


## TODOs

SSH connection keys to eccm.ee  DONE
Location of recordings: 
/home/eccmee1/www/radio1965/streams

To shlef -  not after a week but a day. DONE

Save audio stream -  if required DONE

Joomla articles -  summary shorter. DONE

On open, show dialog, what VÄIN is, "Do not show again" checkbox. Perhaps the same dialog as in Menu entry "Info"?  DONE

Broadcasting:
- signal meter. DONE

PlayerBar 
-- when user pick an options that has a stream, play it immediately. DONE

Joomla articles -  how to delete? At the moment status "archived" works. "unpublised" brings them back. "trashed"?


Webcontent -  what aout youtube and vimeo videos? embed them automatically?

Box -  header title should be clickable the whole row, not only the label (problem when only letter, like "T" )  seems OK.

BroadCast page -  not name (take it from settings now) but Title. DONE

Think what the broadcast notification should be -> {name} on  {channel}

(perhaps) Change package name to org.eccm.vain -- does it break Firebase registration?

"Contributor" role. Password to editor page.
Checkbox "Notify -  never"  (editor)

Add name/author filed to events and where it is needed (connected to registration system)

Database managing page

On Video the seek bar should be below the video. How to do it if fullscreen? DONE

## Konwn problems

When problem with connecting to Icecast -  app crashes (happens in IcecastBroadcaster::teardown() ) DONE

some problem with the Page width in Collectionpage -  element go over or stay smaller than the screen (Android). <- TODO!!

Search does not work on Collection. SEEMS OK.

Video fullscreen dows not fill the screen on mobile devices. FIXED

When video streaming is started, no automatic notification is saved.

Sometimes old stream data stays hanging on player bar or not updated properly.
- when I click on Card on Home page "Tester on air", the PlayerBar still shows "Radio 1965" -  the prvious stram data => The playerBar info is not updated when one clicks on card. It is not even updated when I select the channel from combobox.
FIXED

It is not intuitive to get back to channel selection from playing a file (PlayerBar) FIXED



## Ideas



## Questions

Should the audio streams be saved? What happesn on stream end? "unpublished" ? "shelved"? Result turned into audio/video-file and chenge type in the database?

App name case -  "Väin" | "VÄIN"

What is the text when a person is banned? 