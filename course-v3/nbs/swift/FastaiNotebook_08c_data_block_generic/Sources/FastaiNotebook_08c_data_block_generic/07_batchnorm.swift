/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: 07_batchnorm.ipynb

*/



import Path
import TensorFlow
import Python

public class Reference<T> {
    public var value: T
    public init(_ value: T) { self.value = value }
}

public protocol LearningPhaseDependent: FALayer {
    associatedtype Input
    associatedtype Output
    
    @differentiable func forwardTraining(_ input: Input) -> Output
    @differentiable func forwardInference(_ input: Input) -> Output
}

extension LearningPhaseDependent {
    // This `@differentiable` attribute is necessary, to tell the compiler that this satisfies the FALayer
    // protocol requirement, even though there is a `@differentiating(forward)` method below.
    // TODO: It seems nondeterministically necessary. Some subsequent notebooks import this successfully without it,
    // some require it. Investigate.
    @differentiable
    public func forward(_ input: Input) -> Output {
        switch Context.local.learningPhase {
        case .training:  return forwardTraining(input)
        case .inference: return forwardInference(input)
        }
    }

    @differentiating(forward)
    func gradForward(_ input: Input) ->
        (value: Output, pullback: (Self.Output.TangentVector) ->
            (Self.TangentVector, Self.Input.TangentVector)) {
        switch Context.local.learningPhase {
        case .training:
            return valueWithPullback(at: input) { $0.forwardTraining ($1) }
        case .inference:
            return valueWithPullback(at: input) { $0.forwardInference($1) }
        }
    }
}

public protocol Norm: Layer where Input == Tensor<Scalar>, Output == Tensor<Scalar>{
    associatedtype Scalar
    init(featureCount: Int, epsilon: Scalar)
}

public struct FABatchNorm<Scalar: TensorFlowFloatingPoint>: LearningPhaseDependent, Norm {
    // TF-603 workaround.
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    @noDerivative public var delegates: [(Self.Output) -> ()] = []
    
    // Configuration hyperparameters
    @noDerivative var momentum, epsilon: Scalar
    // Running statistics
    @noDerivative let runningMean, runningVariance: Reference<Tensor<Scalar>>
    // Trainable parameters
    public var scale, offset: Tensor<Scalar>
    
    public init(featureCount: Int, momentum: Scalar, epsilon: Scalar = 1e-5) {
        self.momentum = momentum
        self.epsilon = epsilon
        self.scale = Tensor(ones: [featureCount])
        self.offset = Tensor(zeros: [featureCount])
        self.runningMean = Reference(Tensor(0))
        self.runningVariance = Reference(Tensor(1))
    }
    
    public init(featureCount: Int, epsilon: Scalar = 1e-5) {
        self.init(featureCount: featureCount, momentum: 0.9, epsilon: epsilon)
    }

    @differentiable
    public func forwardTraining(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        let mean = input.mean(alongAxes: [0, 1, 2])
        let variance = input.variance(alongAxes: [0, 1, 2])
        runningMean.value += (mean - runningMean.value) * (1 - momentum)
        runningVariance.value += (variance - runningVariance.value) * (1 - momentum)
        let normalizer = rsqrt(variance + epsilon) * scale
        return (input - mean) * normalizer + offset
    }
    
    @differentiable
    public func forwardInference(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        let mean = runningMean.value
        let variance = runningVariance.value
        let normalizer = rsqrt(variance + epsilon) * scale
        return (input - mean) * normalizer + offset
    }
}

struct BatchNormResult<Scalar : TensorFlowFloatingPoint> : Differentiable{
    var y, batchMean, batchVariance, reserveSpace1, reserveSpace2: Tensor<Scalar>
}

public struct TFBatchNorm<Scalar: TensorFlowFloatingPoint>: LearningPhaseDependent, Norm {
    // Configuration hyperparameters
    @noDerivative var momentum, epsilon: Scalar
    // Running statistics
    @noDerivative let runningMean, runningVariance: Reference<Tensor<Scalar>>
    // Trainable parameters
    public var scale, offset: Tensor<Scalar>
    @noDerivative public var delegates: [(Self.Output) -> ()] = []
    
    public init(featureCount: Int, momentum: Scalar, epsilon: Scalar = 1e-5) {
        self.momentum = momentum
        self.epsilon = epsilon
        self.scale = Tensor(ones: [featureCount])
        self.offset = Tensor(zeros: [featureCount])
        self.runningMean = Reference(Tensor(0))
        self.runningVariance = Reference(Tensor(1))
    }
    
    public init(featureCount: Int, epsilon: Scalar = 1e-5) {
        self.init(featureCount: featureCount, momentum: 0.9, epsilon: epsilon)
    }

    @differentiable
    public func forwardTraining(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        let res = TFBatchNorm<Scalar>.fusedBatchNorm(
            input, scale: scale, offset: offset, epsilon: epsilon)
        let (output, mean, variance) = (res.y, res.batchMean, res.batchVariance)
        runningMean.value += (mean - runningMean.value) * (1 - momentum)
        runningVariance.value += (variance - runningVariance.value) * (1 - momentum)
        return output
     }
    
    @differentiable
    public func forwardInference(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        let mean = runningMean.value
        let variance = runningVariance.value
        let normalizer = rsqrt(variance + epsilon) * scale
        return (input - mean) * normalizer + offset
    }
    
    @differentiable(wrt: (x, scale, offset), vjp: _vjpFusedBatchNorm)
    static func fusedBatchNorm(
        _ x : Tensor<Scalar>, scale: Tensor<Scalar>, offset: Tensor<Scalar>, epsilon: Scalar
    ) -> BatchNormResult<Scalar> {
        let ret = Raw.fusedBatchNormV2(
            x, scale: scale, offset: offset, 
            mean: Tensor<Scalar>([] as [Scalar]), variance: Tensor<Scalar>([] as [Scalar]), 
            epsilon: Double(epsilon))
        return BatchNormResult(
            y: ret.y, batchMean: ret.batchMean, batchVariance: ret.batchVariance,
            reserveSpace1: ret.reserveSpace1, reserveSpace2: ret.reserveSpace2
        )
    }

    static func _vjpFusedBatchNorm(
        _ x : Tensor<Scalar>, scale: Tensor<Scalar>, offset: Tensor<Scalar>, epsilon: Scalar
    ) -> (BatchNormResult<Scalar>, 
          (BatchNormResult<Scalar>.TangentVector) -> (Tensor<Scalar>.TangentVector, 
                                                        Tensor<Scalar>.TangentVector, 
                                                        Tensor<Scalar>.TangentVector)) {
      let bnresult = fusedBatchNorm(x, scale: scale, offset: offset, epsilon: epsilon)
  
        return (
            bnresult, 
            {v in 
                let res = Raw.fusedBatchNormGradV2(
                    yBackprop: v.y, x, scale: Tensor<Float>(scale), 
                    reserveSpace1: bnresult.reserveSpace1, 
                    reserveSpace2: bnresult.reserveSpace2, 
                    epsilon: Double(epsilon))
                return (res.xBackprop, res.scaleBackprop, res.offsetBackprop)
            })
    }
}

public struct ConvBN<Scalar: TensorFlowFloatingPoint>: FALayer {
    // TF-603 workaround.
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    @noDerivative public var delegates: [(Self.Output) -> ()] = []
    public var conv: FANoBiasConv2D<Scalar>
    public var norm: FABatchNorm<Scalar>
    
    public init(_ cIn: Int, _ cOut: Int, ks: Int = 3, stride: Int = 1){
        // TODO (when control flow AD works): use Conv2D without bias
        self.conv = FANoBiasConv2D(cIn, cOut, ks: ks, stride: stride, activation: relu)
        self.norm = FABatchNorm(featureCount: cOut, epsilon: 1e-5)
    }

    @differentiable
    public func forward(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        return norm.forward(conv.forward(input))
    }
}

public struct CnnModelBN: Layer {
    public var convs: [ConvBN<Float>]
    public var pool = FAGlobalAvgPool2D<Float>()
    public var linear: FADense<Float>
    @noDerivative public var delegates: [(Self.Output) -> ()] = []
    
    public init(channelIn: Int, nOut: Int, filters: [Int]){
        let allFilters = [channelIn] + filters
        convs = Array(0..<filters.count).map { i in
            return ConvBN(allFilters[i], allFilters[i+1], ks: 3, stride: 2)
        }
        linear = FADense<Float>(filters.last!, nOut)
    }
    
    @differentiable
    public func callAsFunction(_ input: TF) -> TF {
        // TODO: Work around https://bugs.swift.org/browse/TF-606
        return linear.forward(pool.forward(convs(input)))
    }
}
