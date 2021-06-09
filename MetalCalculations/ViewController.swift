//
//  ViewController.swift
//  MetalCalculations
//
//  此程序主要演示 Metal API 进行 并行运算的示例
//  Created by Duke on 2021/6/8.
//

import UIKit

class ViewController: UIViewController {
    
    private let sizeBuffer1 = 10000000//第1个buffer的size：10w个Float<4个字节>
    private let sizeBuffer2 = 10000000//第2个buffer的size：10w个Float<4个字节>
    private let sizeBufferResult = 10000000//存储结果的Buffer size:10w个Float<4个字节>
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        //
        metalCalculations()
    }
    
    func metalCalculations(){
        //1.获取默认的GPU实例对象(多GPU是多个实例，目前我们只使用一个)
        let gpuDevice = MTLCreateSystemDefaultDevice()
        //2.初始化Metal Objects
        //MetalObjects代表了GPU相关的实体:compiled shaders, memory buffers and textures, as objects
        //从device对象直接创建或间接创建的这些对象的初始化工作，都比较消耗时间，最好只初始化一次，所以可以新建一个对象来存储这些创建的对象
        
        //3.获取Shader<.metal文件>中的函数的引用
        //(1)通过gpuDevice获取MTLLibrary对象(2)通过MTLLibrary对象获取MTLFunction对象(对shader函数的引用)
        let library = gpuDevice?.makeDefaultLibrary()
        let shaderAddFunctionRef = library?.makeFunction(name: "add_arrays")
        //4.准备一个Metal管道<Pipeline>，我们这个例子需要拿到PipelineStateObject
        //为什么需要准备这个Pipeline
        //原因是：上面拿到的shaderAddFunctionRef并不能直接运行，如果想要执行这个Shader函数的引用，就需要创建一个Pipeline
        //一个计算运行管道<ComputePipeline>运行一个单独的计算函数,并且你可以在函数运行之前输入数据，在函数运行之后获取结果数据
        //当创建完了这个Pipeline，运行到这儿的时候，意味着gpuDevice已经为指定的gpu编译完成了这个ShaderFunction
        //这个函数是同步函数，因为比较耗时，所以避免在实时系统中调用这个同步方法
        let computePipelineStateObject = try! gpuDevice?.makeComputePipelineState(function: shaderAddFunctionRef!)
        //5.创建命令队列<CommandQueue>
        //为了发送命令(执行的任务)给GPU，Metal使用 命令队列 来调度 命令
        let commandQueue = gpuDevice?.makeCommandQueue()
        //6.创建数据缓冲区<DataBuffer> 和 将数据载入给GPU
        //官方建议：尽量早创建数据
        //GPU有自己的独立的内存，但是也可以和CPU共享内存
        //为了让你在内存中存储的数据对GPU可见，Metal使用MTLResource对象抽象了内存管理
        //MTLResource代表了当运行命令时，一块GPU可以访问的内存，通过MTLDevice来创建MTLResource
        //这个例子我们创建了三块内存区域，前面两个Buffer用来作为输入参数，后面一个Buffer作为结果返回
        //storageModeShared表示分配的内存区域，CPU和GPU都可以访问
        //因为swift的Float和C语言所占的字节数都是4，这里分配的是字节数容量，所以*4
        let bufferA = gpuDevice?.makeBuffer(length: sizeBuffer1*4, options: .storageModeShared)
        let bufferB = gpuDevice?.makeBuffer(length: sizeBuffer2*4, options: .storageModeShared)
        let bufferResult = gpuDevice?.makeBuffer(length: sizeBufferResult*4, options: .storageModeShared)
        //在CPU端填充bufferA和bufferB
        fillDataToBuffer(with: bufferA,with: bufferB)
        //7.创建命令缓冲区<CommandBuffer>
        let commandBuffer = commandQueue?.makeCommandBuffer()
        //8.创建命令编码器<CommandEncoder>
        //CommandEncoder用于把上面所有的操作都编码成GPU识别的命令，然后嵌入到CommandBuffer中
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        //9.设置pipelineStateObject(代表一个Shader函数<已经被编译成二进制可执行函数了>)和Shader函数的参数
        computeCommandEncoder?.setComputePipelineState(computePipelineStateObject!)
        //设置参数,offset表明Shader函数访问buffer是从buffer的开始位置访问
        //之所以有这个offset参数，是因为你可以传递一个参数，但是从不同的内存位置访问
        computeCommandEncoder?.setBuffer(bufferA, offset: 0, index: 0)//设置Shader函数的第一个参数
        computeCommandEncoder?.setBuffer(bufferB, offset: 0, index: 1)//设置Shader函数的第二个参数
        computeCommandEncoder?.setBuffer(bufferResult, offset: 0, index: 2)//设置Shader函数的第三个参数
        //10.指定线程数量 和 组织形式
        //Metal支持 1维 2维 3维 数组，这个例子使用的是1维数组
        let gridSize = MTLSizeMake(sizeBuffer1, 1, 1)
        //10.1. 指定线程组<ThreadGroup>数量，Metal Grid下细分，这是为了加速GPU
        var threadGroupSize = computePipelineStateObject?.maxTotalThreadsPerThreadgroup
        if threadGroupSize! > sizeBuffer1 {
            threadGroupSize! = sizeBuffer1
        }
        let threadgroupSize = MTLSizeMake(threadGroupSize!, 1, 1)
        //11.Encode the Compute Command to Execute the Threads
        //编码计算命令来执行线程
        computeCommandEncoder?.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        //12.结束计算通道，当没有更多命令添加到通道时，就可以结束计算通道了
        computeCommandEncoder?.endEncoding()
        //13.提交 命令缓冲区 以执行它的命令
        //此时，上面的命令都传送到GPU开始执行了
        commandBuffer?.commit()//此方法为异步方法
        //14.等待 命令缓冲区 执行完成
        NSLog("执行GPU之前")
        commandBuffer?.waitUntilCompleted()
        NSLog("执行GPU之后")
        //14.1 或者可以添加一个回调监听，等待执行完成回调
        //        commandBuffer?.addCompletedHandler{mTLCommandBuffer in
        //            //通过status获取当前commandBuffer的执行所处在的状态
        //            mTLCommandBuffer.status
        //        }
        //15.从Buffer中读取结果
        readResult(bufferA!,bufferB!,bufferResult!)
    }
    
    /**
     填充Buffer
     MTLBuffer代表了没有预定义类型<比如Int等>的一块内存区域(一块连续的byte数组内存)
     但是，当你在Shader中使用buffer时，你需要制定类型
     这意味着你必须将Shader函数中的类型和你来回传递的数据类型必须保持一致
     */
    private func fillDataToBuffer(with bufferA:MTLBuffer?,with bufferB:MTLBuffer?){
        let bufferAPointer = bufferA?.contents()
        if let pointer = bufferAPointer {
            //将原始指针转成FloatArray指针
            let floatArrayPtr = pointer.bindMemory(to: CFloat.self, capacity: sizeBuffer1)
            for index in 0..<sizeBuffer1{
                floatArrayPtr.advanced(by: index).pointee = CFloat(index)
            }
        }
        let bufferBPointer = bufferB?.contents()
        if let pointer = bufferBPointer {
            //将原始指针转成Float指针
            let floatPtr = pointer.bindMemory(to: CFloat.self, capacity: sizeBuffer2)
            //将Float指针转换成指为一块连续内存的 指针
            for index in 0..<sizeBuffer2{
                floatPtr.advanced(by: index).pointee = CFloat(index)
            }
        }
    }
    
    private func readResult(_ bufferA:MTLBuffer,_ bufferB:MTLBuffer,_ bufferResult:MTLBuffer){
        let resultPointer = bufferResult.contents()
        //转换成Float指针
        let bindPtr = resultPointer.bindMemory(to: CFloat.self, capacity: sizeBufferResult)
        print("bufferPtr[1]=\(bindPtr.advanced(by: 2).pointee)")
    }
    
    
}

