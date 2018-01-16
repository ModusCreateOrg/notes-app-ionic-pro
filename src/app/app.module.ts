import { NgModule, ErrorHandler } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { IonicApp, IonicModule } from 'ionic-angular';
import { MyApp } from './app.component';
import { HomePage } from '../pages/home/home';
import { AboutPage } from '../pages/about/about';
import { SettingsPage } from '../pages/settings/settings';
import { TabsControllerPage } from '../pages/tabs-controller/tabs-controller';


import { StatusBar } from '@ionic-native/status-bar';
import { SplashScreen } from '@ionic-native/splash-screen';
import { AppErrorHandlerProvider } from '../providers/app-error-handler/app-error-handler';
import { MonitorPage } from '../pages/monitor/monitor';

@NgModule({
  declarations: [
    MyApp,
    HomePage,
    AboutPage,
    SettingsPage,
    TabsControllerPage,
    MonitorPage
  ],
  imports: [
    BrowserModule,
    IonicModule.forRoot(MyApp)
  ],
  bootstrap: [IonicApp],
  entryComponents: [
    MyApp,
    HomePage,
    AboutPage,
    SettingsPage,
    TabsControllerPage,
    MonitorPage
  ],
  providers: [
    StatusBar,
    SplashScreen,
    { provide: ErrorHandler, useClass: AppErrorHandlerProvider }
  ]
})
export class AppModule {}
