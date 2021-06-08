//
//  addArraysMetal.metal
//  MetalCalculations
//  输入：两个数量相同的Float数组
//  输出：一个数组，数组的每个元素是两个数组各个对应的元素相加后的结果
//  一个.metal文件  ------  一个shader
//  Created by Duke on 2021/6/8.
//

#include <metal_stdlib>
using namespace metal;

//kernel关键字表明：
//1.公用函数<对你的代码可见>
//2.这是一个 计算核心<compute kernel>(或 计算函数)，用一系列线程执行并行计算的函数
//thread_position_in_grid参数关键字表明:
//注意这个参数的语法:c++ attribute syntax:[[attribute]]    具体请查资料
//目前自己的理解:编译器特有的属性，会根据这个属性去执行特定的操作，具体看编译器，所以这里不用管
//这个关键字声明Metal应为每个线程提供一个唯一索引(index)，并将这个索引注入到参数中以供使用
kernel void add_arrays(device const float* inA,
                       device const float* inB,
                       device float* result,
                       uint index [[thread_position_in_grid]]){
    result[index] = inA[index] + inB[index];
}
