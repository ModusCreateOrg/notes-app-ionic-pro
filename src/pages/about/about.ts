import { Component } from '@angular/core';
import { NavController } from 'ionic-angular';
import { Pro } from '@ionic/pro';

@Component({
  selector: 'page-about',
  templateUrl: 'about.html'
})
export class AboutPage {
  // this tells the tabs component which Pages
  // should be each tab's root Page
  constructor(public navCtrl: NavController) {
  }

  /**
   * @author Ahsan Ayaz
   * @desc Triggers an error manually that can be seen on Ionic Monitor
   */
  triggerError() {
    Pro.getApp().monitoring.exception(new Error('My test error'))
  }

}
