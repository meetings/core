MEETIN.GS BETA API DOCUMENTATION. Things might change.

Overview
========

Meetin.gs is a web service which hosts private virtual spaces for all types of
meetings. These spaces can be used to share materials, notes and other
information with meeting participants very easily. It works beautifully even
when participants come from different organizations as interacting with the
system is literally as easy as responding to an email with attachments.

Meetin.gs partner API allows Meetin.gs partners to create these meeting spaces
automatically for their customers to add value to their own services. For
example if you rent a physical room for a meeting, your can provide a virtual
space for sharing meeting materials in the same package.

All you need to provide is your customer's email address and Meetin.gs
will take the process from there onward. If you want to make the process even
smoother for your customer, you can use the API to provide and update fither
information of the customer and of the meeting which the space is created for.

Meetin.gs aims to be a simple service so the API is also designed to be as
simple to use as possible. 


Getting started
===============


Get your partner API key
------------------------

First, [register your partner API key](http://meetin.gs/meetings/partner_api_key/).

The API key you receive allows you to create meeting spaces on Meetin.gs which
match the spaces created with the free plan on [Meetin.gs][].
To offer meeting spaces customized to your brand and with other features in the
Pro package, you can [contact us](sales@meetin.gs) and have your API key attached
to a subdomain like `partner.meetin.gs`.

[Meetin.gs]: http://meetin.gs/

Create a test meeting using curl
--------------------------------

The Meetin.gs API works simply by sending HTTPS requests to our web server with
your partner API key and some parameters inserted in the HTTP parameters. One
commonly used way to send these requests at least in the testing phase is to
use the program `curl` which is almost always installed in any OS X and Linux
installations.

To create a test meeting in meetin.gs for yourself, issue the following command
in your shell with curl:

    curl https://meetin.gs/meetings_jsonapi/create \
        -d 'api_key=YOUR_API_KEY' \
        -d 'creator_email=your@email.com' \
        -d 'title=Apitest meeting' \
        -d 'location=The%20stars' \
        -d 'external_id=apitest'

You should receive the following JSON struct as the return message with data
unique to your newly created meeting:

    {
      result : {
        external_id : 'apitest',
        uid : '1g3h5jk67l3l24krs2sss72@mtn.gs',
        email : 'abc123@mtn.gs',
        room_id_list : [],
        url : 'http://meetin.gs/meeting/enter_meeting/1010/1234'
        creator_url : 'http://meetin.gs/meeting/enter_meeting/1010/1234?email=your@email.com'
      }
    } 

You should now also receive an email from info@meetin.gs which provides a link
to your new meeting space. The email also guides you on how to use the space and
how to invite other participants to join. 


Get a login url for participants 
--------------------------------

In the create call you received a general url and the url to use for the creator
user. If you need to log somebody else in to the area, you can ask for info on
the meeting and specify a different email to log the user in with:

    curl https://meetin.gs/meetings_jsonapi/info \
        -d 'api_key=YOUR_API_KEY' \
        -d 'external_id=apitest' \
        -d 'login_email=other@email.com'

You will get back the generic url and also the url corresponding the requested login email:

    {
      result : {
        external_id : 'apitest',
        uid : '1g3h5jk67l3l24krs2sss72@mtn.gs',
        email : 'abc123@mtn.gs',
        room_id_list : [],
        url : 'http://meetin.gs/meeting/enter_meeting/1010/1234'
        login_email_url : 'http://meetin.gs/meeting/enter_meeting/1010/1234?email=other@email.com'
      }
    } 

You can use these links to start the authentication process for any user. If the
user with the given email is not a participant in the meeting, the user will be
notified of this and a confirmation email will be sent to the meeting creator
which asks whether the user should be invited before the user can actually enter
the space.

Unfortunately at this point we can not give you links which would automatically
log the user in if the user is not already logged in.


Update the location of your test meeting using curl
---------------------------------------------------

Now we use the `external_id` which we provided in the create call to update the
meeting. It is not necessary to provide the `external_id` as you can also use
the returned `uid` but as the `external_id` namespace is tied to your API key,
you can conveniently use the existing unique identifiers in your system to
update the meeting spaces without storing data from meetin.gs to your system:

    curl https://meetin.gs/meetings_jsonapi/update \
        -d 'api_key=YOUR_API_KEY' \
        -d 'external_id=apitest' \
        -d 'old_location=The%20stars' \
        -d 'location=The%20moon'

You should receive the following JSON struct indicating a succesful update:

    {
      result : 1
    }

You should also receive a digest email from info@meetin.gs after a couple of
minutes to inform you that the location of your meeting has changed. Normally
you do not receive digests from operations that you youself have performed but
as this change has been performed through the API, it is not counted as an
operation performed by you and the digest is sent like it will be sent to all
other participants.

### Updating information that has changed ###

To update the agenda, you must supply the old value of the agenda as well as the
new value. The old value is compared to the actual agenda, and the update
operation is aborted if they differ. This ensures that user changes to the
agenda are not accidentally removed.

The same applies also for other information which you want to update except
for the room_id_list parameter which you can update as you wish.


Clean up your test meeting using curl
-------------------------------------

Normally you sould almost never destroy your clients meeting spaces. In the
case of cancellations and payment problems you would just call the `cancel`
endpoint to disassociate the meeting from your partner API key and let the
space fall back to a free meeting space. In some cases like this test it is
however wise to remove the meeting from the system completely by calling the
`remove` endpoint:

    curl https://meetin.gs/meetings_jsonapi/remove \
        -d 'api_key=YOUR_API_KEY' \
        -d 'external_id=apitest'

You should receive the following JSON struct indicating a succesful removal:

    {
      result : 1
    }

Sometimes this call might fail with the reason that the user has already
uploaded information to the Meetin.gs space. In this case this call will act
the same way as `cancel` would have acted.


Help your customer with your data
---------------------------------

To ease your customers the usage of the meeting space you can provide some
additional information in the create call which sets the meeting information and
the customer information for the user. These include things like the date of the
meeting and the profile image for your customers contact person.

Full description of all the parameters you can pass to the create call is
documented in the API Reference section.


API Reference
=============


Basics
------

* HTTPS only
* action determined by URL
* parameters sent as normal HTTP POST parameters containing utf-8 data
* `api_key` must be present as a normal parameter in all requests
* response contains a plaintext JSON object containing utf-8 data
* returned JSON object contains one key, either `error` or `result`
* contents of the result key vary by action
* error key contains an object with keys `code` and `message`

The following chapters document the functionality, parameters accepted and
errors returned by different url endpoints. Parameters with an exclamation
point (!) must be present in the request.

Parameter naming conventions are as follows:

* parameter which ends in _epoch is expected to contain an epoch number.
* parameter which ends in _list are expected to contain a JSON encoded
    array.
* other parameters are expected to be freeform strings unless
    otherwise stated in the documentation.



`https://meetin.gs/meetings_jsonapi/create`
---------------------------------------

+ `api_key` (!)
+ `creator_email` (!)
+ `title`
+ `location`
+ `agenda_html`
+ `agenda_text`
+ `start_epoch`
+ `end_epoch`
+ `creator_first_name`
+ `creator_last_name`
+ `creator_organization`
+ `creator_title`
+ `creator_skype`
+ `creator_phone`
+ `creator_image_url`
+ `creator_timezone`
+ `creator_language`
+ `external_id`
+ `room_id_list`
+ `disable_create_email`

`https://meetin.gs/meetings_jsonapi/info`
-------------------------------------

+ `api_key` (!)
+ `external_id` (!*)
+ `uid` (!*)
+ `login_email`


`https://meetin.gs/meetings_jsonapi/update`
-------------------------------------

+ `api_key` (!)
+ `external_id` (!*)
+ `uid` (!*)
+ `old_title`
+ `old_location`
+ `title`
+ `location`
+ `old_start_epoch`
+ `old_end_epoch`
+ `start_epoch`
+ `end_epoch`
+ `old_agenda_html`
+ `old_agenda_text`
+ `agenda_html`
+ `agenda_text`
+ `room_id_list`


`https://meetin.gs/meetings_jsonapi/cancel`
-------------------------------------

+ `api_key` (!)
+ `external_id` (!*)
+ `uid` (!*)


`https://meetin.gs/meetings_jsonapi/remove`
-------------------------------------

+ `api_key` (!)
+ `external_id` (!*)
+ `uid` (!*)


