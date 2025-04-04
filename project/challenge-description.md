Contract App - April 4 2025
This app will be very challenging to build in 48 hours. It’s very unlikely someone could build this without extensive use of AI, so make sure you are using AI to help as much as possible! I recommend using Cursor with a Pro subscription. Do not have other people help you. If other people help, the submission will not be accepted.
Please fully deploy the app (to Render or Fly.io or similar) and then submit the url to the app well as a link to your repo so I can review the code.
If you submit a fully deployed, working app that meets all the requirements below, on time, I will pay you $3000.
Please build an app that watches certain Slack channels and notion databases for messages or tickets (Notion Page in the Notion database) that contain PII information. If PII information is found, it should remove the message/ticket and DM the author with the content asking them to recreate it without PII in it. This is a real app we need built and if we hire you, we’ll have you integrate this app into our tech stack.
Here’s how it should work:
When:
a message is sent in a Slack channel (that is part of list of watched channels) 
or in a thread in that channel
or when a ticket is added to a notion database
Then:
You should use AI to analyze the contents of the message/ticket for PII information
If the message/ticket contains PII anywhere in the message/ticket (including images, PDF attachments, fields, etc)
The message/ticket is deleted and a DM is sent to the author with the content of the message as a quote block so they can easily recreate their message omitting the PII information.
For Slack, the author will be easy
For notion, you should get the authors email and look up the slack user by the same email
If it does not contain PII, then do nothing
How I’ll test the app:
Set up Slack and Notion so that you can add me to both so I can test your app.
I will send a message in your Slack channel containing PII (in text, an image and a PDF attachment) and make sure it disappears and I get a DM warning me about it
I will add a message without PII and it should not disappear
I will add a ticket to your notion database containing PII (either in text in one of the fields or the ticket content, or in an image) and watch it get deleted and my slack user get a DM notifying me
I will add a ticket to your notion database not containing PII and it wont get deleted
The app should have good tests (Have AI write them).
Once completed, please reply to this Polymer email with the url to the app as well as a link to your repo so I can see the code. Submissions must be made before 7am America/Denver Monday March 10, 2025.
If you don’t quite finish, submit anyway. If no one finishes, I may still hire the best submission and pay that person $3000.
The Jump Hiring Team