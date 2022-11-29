<?php

if(count($_SERVER['argv']) >= 2)
{
    print "Usage: report-resources\n";
    exit(1);
}

$xw = new XMLWriter;

$xw->openMemory();
$xw->setIndent(true);
$xw->setIndentString(' ');
$xw->startDocument( '1.0');

$xw->startElement('resources');
$xw->writeAttribute('xmlns', 'http://apstandard.com/ns/1/resource-output');

$xw->startElement('resource');
$xw->writeAttribute('id', 'disk_usage');
$xw->writeAttribute('value', 0);
$xw->endElement();

$xw->endElement();

$xw->endDocument();
echo $xw->outputMemory();

exit(0);

?>
