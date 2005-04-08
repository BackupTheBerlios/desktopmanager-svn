<?php include "page.php"; startPage("about"); ?>

<!-- begin main content -->
<div id="mainPage">
  <div id="rightBox">
  <div class="box" id="news">
    <h1>Latest News</h1>
<?php
  include "newsItems.php";

  $i = 0;
  echo "<ul>\n";
  while(($i < 5) && ($i < count($newsItems))) {
    $item = $newsItems[$i];
    ?> <li><span class="date"><?php echo $item['date'];?></span>
	    <a href="news.php#item<?php echo $item['date']; 
	    ?>"><?php echo $item['title']; ?></a></li><?php
    $i++;
  }
  echo "</ul>\n";
?>
  </div>
  <div class="box" id="donate">
  <h1>Donate to Desktop Manager</h1>
  <p>Any donations you can make to show your appreciation or to help
  continue the development of Desktop Manager are most welcome.</p>
    <form action="https://www.paypal.com/cgi-bin/webscr" method="post">
  <div style="text-align: center;">
      <input type="hidden" name="cmd" value="_xclick" />
      <input type="hidden" name="business" value="richwareham@users.sourceforge.net" />
      <input type="hidden" name="item_name" value="Desktop Manager" />
      <input type="hidden" name="no_note" value="1" />
      <input type="hidden" name="currency_code" value="GBP" />
      <input type="hidden" name="tax" value="0" />
      <input type="hidden" name="lc" value="GB" />
      <input type="image" src="https://www.paypal.com/en_US/i/btn/x-click-but21.gif" style="border: none;" name="submit" alt="Make payments with PayPal - it's fast, free and secure!" />
  </div>
    </form>
  </div>
  <div class="box" id="license">
    <h1>Licensing</h1>
    <p>This software is released under the terms of the 
    <a href="http://www.gnu.org/copyleft/gpl.html">GNU General Public
    License</a>, see the file COPYING distributed with the app for details.</p>
    <p>To implement virtual desktops, I've had to delve into the internals of
    OS X and reverse-engineer some functionality. There is no official way to
    implement virtual desktops (other programs have to do equally devious
    tricks). Consequently I appologise if this does weird
    things to your system but it works for me.</p>
    <p>You are free to investigate and
    utilise the techniques used by Desktop Manager so long as you respect
    the license it is released under.</p>
    <p style="text-align: center;"><a href="http://developer.berlios.de" title="BerliOS Developer"> <img src="http://developer.berlios.de/bslogo.php?group_id=3463" width="124px" height="32px" border="0" alt="BerliOS Developer Logo"></a></p>
  </div>
  </div>
  <div class="box" id="about">
    <h1>About Desktop Manager</h1>
    <p>Desktop Manager is my own pet project to implement a (hopefully) easy to
    use virtual desktop manager for OS X. I've put it up here in the hope that
    it will be useful to others. Simply run the app and a pager
    should appear in the status bar and on the desktop.</p> 
    <h2>Features</h2>
    <ul>
      <li>Have any number of named virtual 'screens' (up to available memory)
        to arrange your programs on. Have one screen to keep your mail
	programs, one for web-browsing, one for work. The possibilities 
	are almost endless.</li>
      <li>Exciting switch <a href="screenshots.php">transitions</a> to make all
        your Windows/Linux using friends green with envy.</li>
      <li>Control switching via fully configurable 'hotkeys'.</li>
      <li>Get an instant overview of your desktops via a status-bar based
        'pager'.</li>
      <li>Move windows around in desktops via a desktop-based 'pager'.</li>
      <li>Desktop pager compatible with <a href="http://codetek.com">CodeTek VirtualDesktop</a> skins.</li>
      <li>Move windows between desktops easily via status-bar menu or 
        Expos&eacute;-like 'Operations Menu'.</li>
      <li>Sticky window support - have one window on all desktops.</li>
      <li>Active edge support - switch desktop when the mouse moves 
      past the edge of the screen.</li>
      <li>Desktop notification bezel - pops up on desktop switch to help
        you orient yourself.</li>
      <li>Current desktop name available on desktop background to help
        you keep track.</li>
      <li>Small, unobtrusive app - can be made to be totally invisible if
        you want. Designed to get out of your way and act like a part of the
	OS.</li>
    </ul>
  </div>
  <div class="box" id="warning">
    <h1>Important note</h1>
    <div class="warning">
      This software is alpha quality. Use at your own risk. It has only been
      tested with OS X version 10.3 (Panther). On other versions your
      milage may vary.
    </div>
  </div>
</div>
<!-- end main content -->


<?php endPage(); ?>

