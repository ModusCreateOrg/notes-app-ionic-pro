import { Component } from '@angular/core';
import { NavController, NavParams } from 'ionic-angular';
import { Pro } from '@ionic/pro';

@Component({
  selector: 'page-monitor',
  templateUrl: 'monitor.html',
})
export class MonitorPage {
  app;
  wrappedFunction: Function;
  constructor(public navCtrl: NavController) {
    this.app = Pro.getApp();
  }

  /**
   * @author Ahsan Ayaz
   * @desc Triggers an error manually that can be seen on Ionic Monitor
   */
  triggerError() {
    this.app.monitoring.exception(new Error('My triggered error'))
  }

  /**
   * @author Ahsan Ayaz
   * @desc Logs a custom message sent to Ionic Monitor.
   * @param message - the message to log
   * @type - maps to the `level` property of the monitoring.log method's `options` param
   */
  logSomething(message, type) {
    this.app.monitoring.log(message, {level: type});
  }

  /**
   * @author Ahsan Ayaz
   * @desc Calls a provided function instantly and automatically catches any resulting errors.
   */
  callFunctionTrackingError() {
    Pro.getApp().monitoring.call(() => {
      throw new Error('error from monitoring.call');
    })
  }

  /**
   * @author Ahsan Ayaz
   * @desc Wraps the function provided and returns it back. Automatically catches & reports any
   * resulting errors when the returned function is called.
   */
  wrapFunctionTrackingError() {
    this.wrappedFunction = Pro.getApp().monitoring.wrap(() => {
      this.wrappedFunction = null;
      throw new Error('error from monitoring.wrap  ');
    });
  }

  /**
   * @author Ahsan Ayaz
   * @desc Calls the wrapped function set by `wrapFunctionTrackingError` method above
   */
  callWrappedFunction() {
    this.wrappedFunction();
  }
}
