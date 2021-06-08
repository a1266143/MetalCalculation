//
//  ViewController.swift
//  MetalCalculations
//
//  此程序主要演示 Metal API 进行 并行运算的示例
//  Created by Duke on 2021/6/8.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        //
        metalCalculations()
    }
    
    func metalCalculations(){
        //1.获取默认的GPU实例对象
        let gpuDevice = MTLCreateSystemDefaultDevice()
        //2.初始化Metal Objects
        //MetalObjects代表了GPU相关的实体:compiled shaders, memory buffers and textures, as objects
        //从device对象直接创建或间接创建的这些对象的初始化工作，都比较消耗时间，最好只初始化一次，所以可以新建一个对象来存储这些创建的对象
        
        //3.获取Shader<.metal文件>中的方法的引用
        //(1)通过gpuDevice获取MTLLibrary对象(2)通过MTLLibrary对象获取MTLFunction对象
        let library = gpuDevice?.makeDefaultLibrary()
        let shaderAddFunctionRef = library?.makeFunction(name: "add_arrays")
        //4.准备一个Metal管道<Pipeline>，为什么需要准备这个Pipeline
        //原因是：上面拿到的shaderAddFunctionRef并不能直接运行，如果想要执行这个方法的引用，就需要创建一个Pipeline
        
    }


}

