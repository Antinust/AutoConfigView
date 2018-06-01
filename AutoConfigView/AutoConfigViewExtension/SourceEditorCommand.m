//
//  SourceEditorCommand.m
//  AutoConfigViewExtension
//
//  Created by zhuochuncai on 2018/4/24.
//  Copyright © 2018年 zhuochuncai. All rights reserved.
//

#import "SourceEditorCommand.h"

@implementation SourceEditorCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
    
    NSMutableDictionary *propertyTypeAndNames = [NSMutableDictionary dictionaryWithCapacity:1];
    
    
    NSInteger linesCnt = invocation.buffer.lines.count;
    for (int lineIndex =0; lineIndex< linesCnt; lineIndex++) {
        NSString *lineStr = invocation.buffer.lines[lineIndex];
        
        //第一步找到UI控件声明处
        while (lineIndex<linesCnt && ![(lineStr = invocation.buffer.lines[++lineIndex]) containsString:@"@end"]) {
            
            if (![lineStr containsString:@"@property"]) {
                continue;
            }
            
            //@property (strong, nonatomic)  GosTalkCountDownView *talkView;
            NSRange rightBracketRange = [lineStr rangeOfString:@")"];
            NSRange asteriskRange = [lineStr rangeOfString:@"*"];
            NSRange semiColonRange = [lineStr rangeOfString:@";"];
            
            NSString *typeStr = [lineStr substringWithRange:NSMakeRange(rightBracketRange.location+1, asteriskRange.location - rightBracketRange.location -1 )];
            NSString *nameStr = [lineStr substringWithRange:NSMakeRange(asteriskRange.location+1, semiColonRange.location-asteriskRange.location-1)];
            
            typeStr = [typeStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            nameStr = [nameStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            
            [propertyTypeAndNames setObject:typeStr forKey:nameStr];
        }
        
        //第二步找到@implementation
        while (lineIndex<linesCnt && ![(lineStr = invocation.buffer.lines[++lineIndex]) containsString:@"@implementation"]) {
        }
        
        if ([lineStr containsString:@"@implementation"]) {
            
            NSMutableArray *toInsertStrArray = [NSMutableArray arrayWithCapacity:1];
            lineStr = invocation.buffer.lines[++lineIndex];
            
            //addSubViews
            [toInsertStrArray addObject:@""];
            [toInsertStrArray addObject:@"- (void)addSubViews{"];
            [propertyTypeAndNames enumerateKeysAndObjectsUsingBlock:^(NSString* name, NSString* type, BOOL * _Nonnull stop) {
                [toInsertStrArray addObject:[NSString stringWithFormat:@"    [self addSubview: self.%@];",name]];
            }];
            [toInsertStrArray addObject:@"}"];
            
            
            //makeConstraints
            [toInsertStrArray addObject:@""];
            [toInsertStrArray addObject:@"- (void)makeConstraints{"];
            [propertyTypeAndNames enumerateKeysAndObjectsUsingBlock:^(NSString* name, NSString* type, BOOL * _Nonnull stop) {
                [toInsertStrArray addObject:[NSString stringWithFormat:@"    [self.%@ mas_makeConstraints:^(MASConstraintMaker *make) {",name]];
                [toInsertStrArray addObject:@"        make.top.equalTo(self);"];
                [toInsertStrArray addObject:@"        make.center.equalTo(self);"];
                [toInsertStrArray addObject:@"        make.left.right.equalTo(self);"];
                [toInsertStrArray addObject:@"        make.width.height.mas_equalTo(50);"];
                [toInsertStrArray addObject:@"    }];"];
                
                [toInsertStrArray addObject:@""];
            }];
            [toInsertStrArray addObject:@"}"];
            
            
            //gen getters
            [propertyTypeAndNames enumerateKeysAndObjectsUsingBlock:^(NSString* name, NSString* type, BOOL * _Nonnull stop) {
                
                [toInsertStrArray addObject:@""];
                [toInsertStrArray addObject:[NSString stringWithFormat:@"- (%@*)%@{",type,name] ];
                [toInsertStrArray addObject:[NSString stringWithFormat:@"    if (!_%@) {",name] ];
                [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@ = [%@ new];",name,type] ];
                [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@.backgroundColor = [UIColor clearColor];",name] ];
                [toInsertStrArray addObject:[NSString stringWithFormat:@"        //_%@.layer.cornerRadius = 10;",name] ];
                [toInsertStrArray addObject:[NSString stringWithFormat:@"        //_%@.hidden = YES;",name] ];
                
                
                //由于无法调用UIkit类所以，只能通过Type中含有某个关键字来确定是否属于这一类型
                
                if ([type containsString:(@"Button")]) {
                    
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        [_%@ setTitle:DPLocalizedString("") forState:0];",name]];
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        [_%@ setBackgroundImage:[UIImage imageNamed:nil]forState:0];",name]];
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        [_%@ addTarget:self action:@selector(%@Clicked:) forControlEvents:UIControlEventTouchUpInside];",name,name]];
                    
                }else if ([type containsString:(@"Label")]){
                    
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@.text = DPLocalizedString("");",name]];
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@.textColor = [UIColor whiteColor];",name]];
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@.textAlignment = NSTextAlignmentCenter;",name]];
                    
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@.numberOfLines = 0;",name]];
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@.font = [UIFont systemFontOfSize:14];",name]];
                    
                }else if ([type containsString:(@"ImageView")]){
                    
                    [toInsertStrArray addObject:[NSString stringWithFormat:@"        _%@.image = [UIImage imageNamed:StrObj()];",name]];//
                    
                }else{
                    
                }
                
                
                [toInsertStrArray addObject:@"    }"];
                [toInsertStrArray addObject:[NSString stringWithFormat:@"    return _%@;",name]];
                [toInsertStrArray addObject:@"}"];
            }];
            
            [invocation.buffer.lines insertObjects:toInsertStrArray atIndexes: [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(lineIndex+1, toInsertStrArray.count)]];
        }
    }
    
    completionHandler(nil);
}

@end
