<?php include "page.php"; startPage("news"); ?>

<!-- begin main content -->
<div id="mainPage">
  <?php
  include "newsItems.php";

  $i = 0;
  while(($i < count($newsItems))) {
    $item = $newsItems[$i];
    ?> 
	    <div class="box">
	    <a name="item<?php echo $item['date']; ?>"></a>
	    <h1><?php echo $item['date']." ".$item['title']; ?></h1>
	    <?php echo $item['contents']; ?>
	    </div>
    <?php
    $i++;
  }
  ?>
</div>
<!-- end main content -->


<?php endPage(); ?>

