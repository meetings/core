dojo.provide("dicole.meetings.main");

// Plugins
dojo.require("dicole.meetings.vendor.modernizr");
dojo.require("dicole.meetings.vendor.lodash");
dojo.require("dicole.meetings.vendor.jquery");
dojo.require("dicole.meetings.vendor.jed");
dojo.require("dicole.meetings.vendor.backbone-min");
dojo.require("dicole.meetings.vendor.infiniscroll");
dojo.require("dicole.meetings.vendor.moment");
dojo.require("dicole.meetings.vendor.zclip.zclip");
dojo.require("dicole.meetings.vendor.jquerylazyload");
dojo.require("dicole.meetings.vendor.addressbook");
dojo.require("dicole.meetings.vendor.btdcalendar");
dojo.require("dicole.meetings.vendor.sortable");
dojo.require("dicole.meetings.vendor.humanize-duration");
dojo.require("dicole.meetings.vendor.jstz");
dojo.require("dicole.meetings.vendor.payment");

// App skeleton
dojo.require("dicole.meetings.app");
dojo.require("dicole.meetings.vendor.countries");

// Generic views
dojo.require("dicole.meetings.views.baseCollectionView");
dojo.require("dicole.meetings.views.headerView");
dojo.require("dicole.meetings.views.footerView");
dojo.require("dicole.meetings.views.newsView");

// Summary views
dojo.require("dicole.meetings.views.summaryHighlightView");
dojo.require("dicole.meetings.views.summaryLoadingContactsView");
dojo.require("dicole.meetings.views.summaryMeetingView");
dojo.require("dicole.meetings.views.summaryNavView");
dojo.require("dicole.meetings.views.summaryPastView");
dojo.require("dicole.meetings.views.summaryUpcomingView");

// General views
dojo.require("dicole.meetings.views.connectionErrorView");
dojo.require("dicole.meetings.views.sellProView");
dojo.require("dicole.meetings.views.upgradeSuccessView");
dojo.require("dicole.meetings.views.upgradeCoverView");
dojo.require("dicole.meetings.views.upgradePayView");
dojo.require("dicole.meetings.views.userSettingsView");
dojo.require("dicole.meetings.views.notificationsView");

// Meetme views
dojo.require("dicole.meetings.views.meetmeCalendarView");
dojo.require("dicole.meetings.views.meetmeCoverView");
dojo.require("dicole.meetings.views.meetmeConfigView");
dojo.require("dicole.meetings.views.meetmeShareView");
dojo.require("dicole.meetings.views.wizardProfileView");
dojo.require("dicole.meetings.views.wizardAppsView");
dojo.require("dicole.meetings.views.meetmeCalendarOptionsView");
dojo.require("dicole.meetings.views.meetmePresetFilesView");
dojo.require("dicole.meetings.views.meetmeClaimView");
dojo.require("dicole.meetings.views.meetmeBgSelectorView");
dojo.require("dicole.meetings.views.meetmeSuccessView");

// Meeting views
dojo.require("dicole.meetings.views.meetingMaterialUploadsView");
dojo.require("dicole.meetings.views.meetingLctView");
dojo.require("dicole.meetings.views.meetingTopView");
dojo.require("dicole.meetings.views.meetingSettingsView");

// Agent booking views
dojo.require("dicole.meetings.views.agentBookingView");
dojo.require("dicole.meetings.views.agentBookingConfirmView");

// Agent booking public views
dojo.require("dicole.meetings.views.agentBookingPublicView");
dojo.require("dicole.meetings.views.agentBookingPublicConfirmView");

// Agent absences views
dojo.require("dicole.meetings.views.agentAbsencesView");

// Agent admin views
dojo.require("dicole.meetings.views.agentAdminView");

// Agent manage views
dojo.require("dicole.meetings.views.agentManageView");

// Models
dojo.require("dicole.meetings.models.userModel");
dojo.require("dicole.meetings.models.meetingModel");
dojo.require("dicole.meetings.models.matchmakerModel");
dojo.require("dicole.meetings.models.newsModel");
dojo.require("dicole.meetings.models.notificationModel");
dojo.require("dicole.meetings.models.matchmakerLockModel");

// Collections
dojo.require("dicole.meetings.collections.meetingCollection");
dojo.require("dicole.meetings.collections.matchmakerCollection");
dojo.require("dicole.meetings.collections.newsCollection");
dojo.require("dicole.meetings.collections.notificationCollection");

// Routers
dojo.require("dicole.meetings.router");
