//
//  ViewController.m
//  CrashProtector
//
//  Created by Jonathan on 2018/1/12.
//  Copyright © 2018年 Jonathan. All rights reserved.
//

#import "ViewController.h"
#import "AViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *btn  = [[UIButton alloc] initWithFrame:CGRectMake(30, 100, 100, 60)];
    [btn setTitle:@"Jump" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(jump) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];

    UIButton *btn2  = [[UIButton alloc] initWithFrame:CGRectMake(30, 200, 100, 60)];
    [btn2 setTitle:@"Send" forState:UIControlStateNormal];
    [btn2 setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [btn2 addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn2];
}

- (void)jump
{
    AViewController *vc = [[AViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)send
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CrashNotification" object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
