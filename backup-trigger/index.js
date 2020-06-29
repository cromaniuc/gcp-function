'use strict';

const {google} = require('googleapis');
let sqlAdmin = google.sqladmin('v1beta4');
const {auth} = require("google-auth-library");


exports.backup = (data, context) => {
  
  async function deleteOldBackupsAndCreateNewOne() {

    const authRes = await auth.getApplicationDefault();
    let authClient = authRes.credential;

    const pubSubMessage = data;
    const messageContent = Buffer.from(pubSubMessage.data, 'base64').toString()
    const thirtyFiveDaysOfBackup = 35;

    console.log("Message content:" + messageContent);

    let project = process.env.PROJECT_ID
    let instance = process.env.INSTANCE_NAME
      
    console.log("Running for project:" + project + " and instance: " + instance);

    let request = {
      project: project,
      instance: instance,
      auth: authClient
    };

    sqlAdmin.backupRuns.list(request, function(err, response) {

      if (err) {
        console.error("Error at list:" + err);
        return;
      }

      let referenceDate = new Date();
      referenceDate.setDate(referenceDate.getDate() - thirtyFiveDaysOfBackup);

      let toBeDeleted = response.data.items.filter(function (el) {
        
        return el.type === "ON_DEMAND" && new Date(el.endTime) < new Date(referenceDate)
      });
      
      toBeDeleted.forEach(element => {

        console.log("To be deleted: " + element);

        request.id = element.id

        sqlAdmin.backupRuns.delete(request, function(err, response) {
          if (err) {
            console.error("Error at delete:" + err);
            return;
          }
          console.log("Delete response: " + JSON.stringify(response, null, 2));
        });
      });
    });


    sqlAdmin.backupRuns.insert(request, function(err, response) {
      if (err) {
        console.error("Error at insert: " + err);
        return;
      }

      console.log("Trigger manual backup response: " + JSON.stringify(response.data, null, 2));

    });
  }
  deleteOldBackupsAndCreateNewOne();
};




