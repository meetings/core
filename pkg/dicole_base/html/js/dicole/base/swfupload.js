dojo.provide('dicole.base.swfupload');
// required in controller because trying to package caused problems in IEs

// this seemed to work if the initial var SWFUpload was replaced with 
// SWFUpload = function... (without the "var") so it appeared in the
// global scope also for IE's but this requires more testing
