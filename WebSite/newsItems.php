<?php
global $newsItems;

$newsItems = array(
  array( 'date' => '8-Apr-05', 'title' => 'Moved to BerliOS.de',
          'contents' => '<p>The Desktop Manager site and project has moved to <a href="http://developer.berlios.de/">BerliOS</a></p>'),
  array( 'date' => '16-Nov-04', 'title' => 'DM Review',
	  'contents' => '<p>A <a href="http://apple-x.net/modules.php?op=modload&name=News&file=article&sid=1181&mode=thread&order=0&thold=0">review</a> of Desktop Manager has been posted to <a href="http://apple-x.net/">apple-x.net</a> and pretty sweet it is too. I\'ve been working hard on splitting DM into smaller sub-components and documenting them so be on the lookout for <em>WorkspaceKit</em> - a framework which will allow you to write your own (better?) DM clone.</p>'),
  array( 'date' => '20-Jul-04', 'title' => 'DM ebuild',
	  'contents' => '<p>To celebrate the release of <a href="http://www.metadistribution.org/macos/">Gentoo for Mac OS</a>, I\'ve made a little <a href="http://sourceforge.net/project/showfiles.php?group_id=86417&package_id=124449">ebuild</a> for it to allow you to emerge Desktop Manager if you so wish. Please note that I just hacked this together last night so its probably not the \'official way\'.</p><p>To install, change to your portage directory and untar the file, yous should then be able to <tt>emerge DesktopManager</tt>. If there is enough demand I\'ll try to knock up a fetch-latest-source-from-arch-and-compile version.</p>'),
  array( 'date' => '20-Jul-04', 'title' => 'New webpage',
	  'contents' => '
<p>I re-designed the Desktop Manager website a little to make
it a little easier to update and organise things. Hope you like it.</p>
'),
  array( 'date' => '12-Jul-04', 'title' => '0.5.2-rc2 Released',
	  'contents' => '
   <p>And another release, rc2.</p>

    <ul>
<li>[NEW] Sticky windows should work now. Try invoking the operations menu over 
	a window (default hotkey Command-Opt-O). The UI for this will improve.
</li><li>[NEW] Length of time that desktop switch notification bezel remains on 
	screen is now configurable. (request from Jon Walton)
</li><li>[NEW] \'Collect windows to one desktop on exit\' is now a preference rather 
	than a dialogue box which pops up on exit.
</li><li>[FIX] More multi-monitor fizes for placement of desktop pager. Hiding
	may still be a little funky.
</li><li>[FIX] Re-wrote some of the internal window list handling to (hopfully) be a 
	little lighter on memory. Fixed a (tiny) mem. leak in the process.
    </li></ul>'),
  array( 'date' => '9-Jul-04', 'title' => '0.5.2-rc1 Released',
	  'contents' => '
<p>I\'ve managed to find a bit more time recently and been tidying up my
    backlog of patches for Desktop Manager. I\'ve put a 0.5.2 
    <a href="http://sourceforge.net/project/showfiles.php?group_id=86417">release
    candidate</a> up for people to play with. There should be some support 
    for multi-monitor setups in this version along with a few bug fixes which
    have been annoying people. Can people with multi-monitor setups please
    test.</p>

    <p>Also the arch repository has moved to <a href="http://lotsofnakedwomen.com/arch/">http://lotsofnakedwomen.com/arch/</a> while I wait for the old
    domain to be transferred.</p>
    
    <ul>
    <li>[NEW] New icons. (Glen Gear )
    </li><li>[NEW] \'Fast desktop create\', hot-key triggered desktop creation. 
	(Christopher A. Watford)
    </li><li>[NEW] Switching to an application via shift-clicking in the Dock 
	switches to an appropriate desktop. (me based on patch from Mike 
	Gorski )
    </li><li>[NEW] Started adding some code to be multi-screen aware. (me)
    </li><li>[NEW] Core-code is now a private shared framework. First stage in
	exposing functionality to outside 3rd party apps. (me)
    </li><li>[NEW] Hot-key preferences have been re-written (again). Now configuration
	is done similarly to key bindings in other Apple apps. Still unable
	to test with Unicode keyboard but shouldn\'t crash if it can\'t work out
	what you typed :). (me)
    </li><li>[NEW] Hot-keys can now be disabled via preferences pane. Please stop 
	begging for this now... (me)
    </li><li>[IMP] Moving windows between desktops is faster. Found some more secrets 
	buried inside CoreGraphics. (me)
    </li><li>[IMP] Active Edges now use fewer resources. (me)
    </li><li>[IMP] Desktop pager behaviour changed slightly. Now anchored to one 
	corner/side of the screen. Auto-hides like the Dock. Position set via
	preferences. (me)
    </li><li>[FIX] Switching desktop via statusbar now correctly uses transitions. (me)
    </li><li>[FIX] Switching via active edges now centres the mouse after a switch 
	if set in prefs. (me)
    </li><li>[FIX] Some memory leaks detected and fixed. Still uses quite a chunk of 
	memory but I think a lot of that is shared with the WindowServer. (me)
    </li><li>[FIX] Double-free in active edges now fixed.
    </li><li>[FIX] Fixed some problems with panels and draws. Some problems still
    	remain however.
    </li></ul>'),
  array( 'date' => '4-Jul-04', 'title' => 'Rich Wareham Interview',
	  'contents' => '
<p>An interview with Rich Wareham, the Desktop Manager lead developer, was
<a href="http://www.drunkenblog.com/drunkenblog-archives/000300.html">released</a> today. Enjoy!</p>
'),
  array( 'date' => '12-Feb-04', 'title' => 'We\'re not dead',
	  'contents' => '
<p>DM development isn\'t dead! My iBook was for a while but that is fixed now. I\'ve put up the current ChangeLog for what will become 0.5.2 once it is released. Please check with it before e-mailing me with feature requests. Thanks.</p>
'),
  array( 'date' => '12-Feb-04', 'title' => '0.5.1 Released',
	  'contents' => '
	<p>DM 0.5.1 has been/will be released and the change log is below. This is a mop-up
    release to try to file down some of the rough edges from 0.5.0 and clear my patch
    backlog. There are a fair few bug-fixes and small usability improvements including
    some crash-fixes. I will be concentrating on multiple-monitor support for 0.5.2 [ SO
    STOP E-MAILING PLEASE! :) ].</p><p>
    More importantly the icons for Desktop Manager suck IMHO. I am no graphic designer.
    If any kind soul feels they could do better, please drop me an e-mail. Ideally I\'d
    like something as pretty as the icons on the new Mozilla FireFox browser. Eternal
    fame in the About Box shall be thine reward.</p>
    <p>Grab the latest version (and source) <a href="http://sourceforge.net/project/showfiles.php?group_id=86417">from
      the SourceForge file-release section</a>.</p> 
'),
/*
  array( 'date' => '4-Jul-04', 'title' => 'Rich Wareham Interview',
	  'contents' => '
'),
*/
);

?>
