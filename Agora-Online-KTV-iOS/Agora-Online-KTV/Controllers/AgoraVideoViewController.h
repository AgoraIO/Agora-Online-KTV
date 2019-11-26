//
//  MainViewController.h
//  Agora-Online-KTV
//
//  Created by 湛孝超 on 2018/4/25.
//  Copyright © 2018年 湛孝超. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AgoraRtcKit/AgoraRtcEngineKit.h>

@interface AgoraVideoViewController : UIViewController
@property (copy, nonatomic) NSString *roomName;
@property (assign, nonatomic) AgoraClientRole clientRole;
@property (assign, nonatomic) AgoraVideoProfile videoProfile;

@end
