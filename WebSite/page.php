<?php echo '<?xml version="1.0" encoding="utf-8"?>'; 

$pages = array(
  'about' => array( 'About', 'About Desktop Manager', 'index.php' ),
  'blog' => array( 'Rich\'s Blog', 'Blog', 'http://livejournal.com/users/filecoreinuse/' ),
  'news' => array( 'News', 'Project News', 'news.php' ),
  'download' => array( 'Download', 'Project Downloads', 'download.php' ),
  'screenshots' => array( 'Screenshots', 'Screenshots', 'screenshots.php' ),
  'faq' => array( 'FAQ', 'Frequently Asked Questions', 'faq.php' ),
  'project' => array( 'Project Page', '', 'http://sf.net/projects/wsmanager/' ),
);

function startPage($id) {
  global $pages;
  ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-GB" lang="en-GB">
<head>
  <title><?php echo $pages[$id][1] ?></title>
  <link rel="stylesheet" type="text/css" href="style/navigation.css" />
  <link rel="stylesheet" type="text/css" href="style/boxes.css" />
  <link rel="stylesheet" type="text/css" href="style/main.css" />
</head>
<body>

<!-- begin navigation menu -->
<div id="navigationBar">
  <table>
    <tr>
      <td class="placeholder" />
      <?php
      foreach ($pages as $key => $value) {
        ?> <td<?php if($key == $id) { echo ' id="activeTab"'; }
		?>><a href="<?php echo $pages[$key][2]; ?>"><?php 
		echo $pages[$key][0]; ?></a></td> <?php
      }
      ?>
      <td class="placeholder" />
    </tr>
  </table>
</div>
<!-- end navigation menu -->
  <?php
}

function endPage() {
?>
<!-- begin footer -->
<div id="footer">
  <p>Content Copyright &copy; 2003, 2004 <a 
    href="mailto:richwareham -at- users -d0t- sourceforge -dot- net">Richard
    Wareham</a>.</p>
  <p>Some icons from Crystal SVG theme by <a href="http://www.everaldo.com">Everaldo</a>.</p>
</div>
<!-- end footer -->
</body>
</html>	
<?php
}

?>
