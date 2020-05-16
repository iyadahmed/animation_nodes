import cython
from libc.math cimport sqrt
from .. matrix.c_utils import* 
from libc.math cimport M_PI as PI
from ... math cimport abs as absNumber
from mathutils import Matrix, Euler, Vector
from ... math import matrix4x4ListToEulerList
from ... libs.FastNoiseSIMD.wrapper import PyNoise
from ... algorithms.lists.random import generateRandomVectors
from ... algorithms.random import uniformRandomDoubleWithTwoSeeds, getRandom3DVector
from ... nodes.number.c_utils import range_DoubleList_StartStop, mapRange_DoubleList_Interpolated 
from ... data_structures cimport (
    DoubleList, FloatList,VirtualMatrix4x4List,
    Vector3DList, EulerList, Matrix4x4List,
    VirtualVector3DList, VirtualEulerList, VirtualFloatList, VirtualDoubleList,
    Action, ActionEvaluator, PathIndexActionChannel,
    BoundedAction, BoundedActionEvaluator,Color,
    ColorList, PolygonIndicesList, IntegerList, PolySpline, BezierSpline, Interpolation
)
from ... math cimport (
    add, subtract, multiply, divide_Save, modulo_Save,
    sin, cos, tan, asin_Save, acos_Save, atan, atan2, hypot,
    power_Save, floor, ceil, sqrt_Save, invert, reciprocal_Save,
    snap_Save, copySign, floorDivision_Save, logarithm_Save,
    Vector3, Euler3, Matrix4, toMatrix4,toVector3,multMatrix4, toPyMatrix4,
    invertOrthogonalTransformation,setTranslationRotationScaleMatrix,
    setRotationXMatrix, setRotationYMatrix, setRotationZMatrix,
    setRotationMatrix, setTranslationMatrix, setIdentityMatrix,
    setScaleMatrix,setMatrixTranslation,transposeMatrix_Inplace
)   

def matrixlerp(Matrix4x4List matricesA, Matrix4x4List matricesB, DoubleList influences):
    cdef Py_ssize_t count = max(matricesA.getLength(),matricesB.getLength())
    cdef Py_ssize_t i
    cdef Matrix4x4List out_matrixlist = Matrix4x4List(length = count)
    cdef VirtualMatrix4x4List matrixlistA = VirtualMatrix4x4List.create(matricesA, Matrix.Identity(4))
    cdef VirtualMatrix4x4List matrixlistB = VirtualMatrix4x4List.create(matricesB, Matrix.Identity(4))
    cdef VirtualDoubleList influencess = VirtualDoubleList.create(influences, 0)
    for i in range(count):
        out_matrixlist[i]= matrixlistA[i] . lerp( matrixlistB[i], influencess[i] )  
    return out_matrixlist
 
def getTextureColors_moded(texture, Vector3DList locations, float multiplier):
    cdef long amount = locations.length
    cdef DoubleList reds = DoubleList(length = amount)
    cdef DoubleList greens = DoubleList(length = amount)
    cdef DoubleList blues = DoubleList(length = amount)
    cdef DoubleList alphas = DoubleList(length = amount)
    cdef ColorList colors = ColorList(length = amount)
    cdef float r, g, b, a
    for i in range(amount):
        r, g, b, a = texture.evaluate(locations[i])
        reds.data[i] = r*multiplier
        greens.data[i] = g*multiplier
        blues.data[i] = b*multiplier
        alphas.data[i] = a*multiplier
        colors.data[i] = Color(r, g, b, a)
    return colors, reds, greens, blues, alphas

def getTexturegreys(texture, Vector3DList locations, float multiplier):
    cdef long amount = locations.length
    cdef DoubleList greys = DoubleList(length = amount)
    cdef float r, g, b, a
    for i in range(amount):
        r, g, b, a = texture.evaluate(locations[i])
        greys.data[i] = ((r+g+b)/3)*multiplier
    return greys 
      
def matrix_lerp(Matrix4x4List mA, Matrix4x4List mB, DoubleList influences):
    cdef Vector3DList tA = extractMatrixTranslations(mA)
    cdef Vector3DList tB = extractMatrixTranslations(mB)
    cdef EulerList rA = extractMatrixRotations(mA)
    cdef EulerList rB = extractMatrixRotations(mB)
    cdef Vector3DList sA = extractMatrixScales(mA)
    cdef Vector3DList sB = extractMatrixScales(mB)
    cdef int count = max(mA.getLength(), mB.getLength())
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(tA, (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(rA, (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(sA, (1, 1, 1))
    for i in range(count):
        translations_out.get(i).x = tA.data[i].x * (1-influences.data[i]) + tB.data[i].x * influences.data[i]
        translations_out.get(i).y = tA.data[i].y * (1-influences.data[i]) + tB.data[i].y * influences.data[i]
        translations_out.get(i).z = tA.data[i].z * (1-influences.data[i]) + tB.data[i].z * influences.data[i]
        rotations_out.get(i).x = rA.data[i].x * (1-influences.data[i]) + rB.data[i].x * influences.data[i]
        rotations_out.get(i).y = rA.data[i].y * (1-influences.data[i]) + rB.data[i].y * influences.data[i]
        rotations_out.get(i).z = rA.data[i].z * (1-influences.data[i]) + rB.data[i].z * influences.data[i]
        scales_out.get(i).x = sA.data[i].x * (1-influences.data[i]) + sB.data[i].x * influences.data[i]
        scales_out.get(i).y = sA.data[i].y * (1-influences.data[i]) + sB.data[i].y * influences.data[i]
        scales_out.get(i).z = sA.data[i].z * (1-influences.data[i]) + sB.data[i].z * influences.data[i]      
    return composeMatrices(count, translations_out, rotations_out, scales_out)

def vector_lerp(Vector3DList vectorsA, Vector3DList vectorsB, DoubleList influences):
    cdef Py_ssize_t count = max(vectorsA.getLength(), vectorsB.getLength())
    cdef Py_ssize_t i
    cdef Vector3DList out_vectorlist = Vector3DList(length = count)
    for i in range(count):
        out_vectorlist.data[i].x = vectorsA.data[i].x * (1-influences.data[i]) + vectorsB.data[i].x * influences.data[i]
        out_vectorlist.data[i].y = vectorsA.data[i].y * (1-influences.data[i]) + vectorsB.data[i].y * influences.data[i]
        out_vectorlist.data[i].z = vectorsA.data[i].z * (1-influences.data[i]) + vectorsB.data[i].z * influences.data[i]
    return out_vectorlist

def euler_lerp(EulerList eulersA, EulerList eulersB, DoubleList influences):
    cdef Py_ssize_t count = max(eulersA.getLength(), eulersB.getLength())
    cdef Py_ssize_t i
    cdef EulerList out_eulerlist = EulerList(length = count)
    for i in range(count):
        out_eulerlist.data[i].x = eulersA.data[i].x * (1-influences.data[i]) + eulersB.data[i].x * influences.data[i]
        out_eulerlist.data[i].y = eulersA.data[i].y * (1-influences.data[i]) + eulersB.data[i].y * influences.data[i]
        out_eulerlist.data[i].z = eulersA.data[i].z * (1-influences.data[i]) + eulersB.data[i].z * influences.data[i]
    return out_eulerlist

def generateRandomColors(Py_ssize_t count, Py_ssize_t seed, float scale, bint normalized):
    cdef Py_ssize_t i
    cdef Vector3DList randomVectors = generateRandomVectors(seed, count, scale, normalized)
    cdef ColorList colors = ColorList(length = count)
    for i in range(count):
        r = absNumber(randomVectors.data[i].x)
        g = absNumber(randomVectors.data[i].y)
        b = absNumber(randomVectors.data[i].z)
        colors.data[i] = Color(r, g, b, 1)
    return colors  

def inheritanceCurveOld(Vector3DList vA, Vector3DList vB, Vector3DList pathPoints, float varMin, float varMax, 
                            float randomScale, float smoothness, DoubleList influences, resolution):

    cdef Py_ssize_t i, j
    cdef Py_ssize_t count = vA.getLength()
    cdef Py_ssize_t pathCount = pathPoints.getLength()
    cdef float parameter, newParameter, randomNumber
    cdef Vector3 v
    cdef Vector3DList newPoints = Vector3DList(length = count)
    cdef FloatList radii =  FloatList(length = pathCount + 2)
    cdef FloatList tilts =  FloatList(length = pathCount + 2)
    cdef Vector3DList handles = Vector3DList(length = pathCount + 2)
    cdef Vector3DList randomVectors = generateRandomVectors(1, count, randomScale, False)
    radii.fill(0)
    tilts.fill(0)
    handles.fill([0,0,0])
    for i in range(count):
        newSplinePoints = Vector3DList()
        newSplinePoints.append(vA[i])
        for j in range(pathCount):
            v.x = pathPoints.data[j].x + randomVectors.data[i].x
            v.y = pathPoints.data[j].y + randomVectors.data[i].y
            v.z = pathPoints.data[j].z + randomVectors.data[i].z
            newSplinePoints.append(Vector((v.x, v.y, v.z)))
        newSplinePoints.append(vB[i])
        if smoothness == 0:
            newSpline = PolySpline(newSplinePoints, radii, tilts, False)
        else:    
            newSpline = BezierSpline(newSplinePoints, handles, handles, radii, tilts, False)
            newSpline.smoothAllHandles(smoothness)
        newSpline.ensureUniformConverter(resolution)
        randomNumber = uniformRandomDoubleWithTwoSeeds(i, 0, varMin, varMax)
        parameter = (1.0 + randomNumber) * influences[i]
        newParameter = min(max(parameter, 0), 1)
        newParameter = newSpline.toUniformParameter(newParameter)
        newPoints[i] = newSpline.evaluatePoint(newParameter)
    return newPoints 

def stepEffector(Matrix4x4List matrices, Vector3DList v, EulerList e, Vector3DList s, DoubleList influences, 
                        Interpolation interpolation, double minValue, double maxValue, bint clamp):
    cdef Vector3DList tA = extractMatrixTranslations(matrices)
    cdef EulerList rA = extractMatrixRotations(matrices)
    cdef Vector3DList sA = extractMatrixScales(matrices)
    cdef int count = matrices.getLength()
    cdef double varMin = 0, varMax = 1
    if not clamp:
        varMin = minValue
        varMax = maxValue   
    cdef DoubleList strengths = range_DoubleList_StartStop(count, 0.00, 1.00)
    cdef DoubleList interpolatedStrengths = mapRange_DoubleList_Interpolated(strengths, interpolation, 0, 1, varMin, varMax)
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(tA, (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(rA, (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(sA, (1, 1, 1))
    for i in range(count):
        strength = interpolatedStrengths.data[i]
        if clamp:
            translations_out.get(i).x = tA.data[i].x + max(min(influences.data[i] * v.data[0].x * strength, maxValue), minValue)
            translations_out.get(i).y = tA.data[i].y + max(min(influences.data[i] * v.data[0].y * strength, maxValue), minValue)
            translations_out.get(i).z = tA.data[i].z + max(min(influences.data[i] * v.data[0].z * strength, maxValue), minValue)
            rotations_out.get(i).x = rA.data[i].x + max(min(influences.data[i] * e.data[0].x * strength, maxValue), minValue)
            rotations_out.get(i).y = rA.data[i].y + max(min(influences.data[i] * e.data[0].y * strength, maxValue), minValue)
            rotations_out.get(i).z = rA.data[i].z + max(min(influences.data[i] * e.data[0].z * strength, maxValue), minValue)
            scales_out.get(i).x = sA.data[i].x + max(min(influences.data[i] * s.data[0].x * strength, maxValue), minValue)
            scales_out.get(i).y = sA.data[i].y + max(min(influences.data[i] * s.data[0].y * strength, maxValue), minValue) 
            scales_out.get(i).z = sA.data[i].z + max(min(influences.data[i] * s.data[0].z * strength, maxValue), minValue)
        else:
            translations_out.get(i).x = tA.data[i].x + influences.data[i] * v.data[0].x * strength
            translations_out.get(i).y = tA.data[i].y + influences.data[i] * v.data[0].y * strength
            translations_out.get(i).z = tA.data[i].z + influences.data[i] * v.data[0].z * strength
            rotations_out.get(i).x = rA.data[i].x + influences.data[i] * e.data[0].x * strength
            rotations_out.get(i).y = rA.data[i].y + influences.data[i] * e.data[0].y * strength
            rotations_out.get(i).z = rA.data[i].z + influences.data[i] * e.data[0].z * strength
            scales_out.get(i).x = sA.data[i].x + influences.data[i] * s.data[0].x * strength
            scales_out.get(i).y = sA.data[i].y + influences.data[i] * s.data[0].y * strength 
            scales_out.get(i).z = sA.data[i].z + influences.data[i] * s.data[0].z * strength          
    return composeMatrices(count, translations_out, rotations_out, scales_out), interpolatedStrengths           

def inheritanceCurveVector(Vector3DList vA, Vector3DList vB, Vector3DList splinePoints, float randomScale, DoubleList influences):
    cdef Py_ssize_t i, j, bIndex, aIndex
    cdef Py_ssize_t count = vA.getLength()
    cdef Py_ssize_t splinePointCount = splinePoints.getLength()
    cdef Py_ssize_t innerLength = splinePointCount + 2
    cdef double f, influence
    cdef Vector3DList out_vectorlist = Vector3DList(length = count)
    cdef Vector3DList innerVectorList = Vector3DList(length = innerLength)
    cdef Vector3DList randomVectors = generateRandomVectors(1, count, randomScale, False)
    for i in range(count):
        innerVectorList.data[0] = vA.data[i]
        for j in range(splinePointCount):
            innerVectorList.data[j+1].x = splinePoints.data[j].x + randomVectors.data[i].x
            innerVectorList.data[j+1].y = splinePoints.data[j].y + randomVectors.data[i].y
            innerVectorList.data[j+1].z = splinePoints.data[j].z + randomVectors.data[i].z
        innerVectorList.data[innerLength - 1] = vB.data[i]
        f = influences.data[i] * (innerLength - 1)
        influence = f % 1 
        bIndex = int(max(min(floor(f), innerLength - 1), 0))
        aIndex = int(max(min(ceil(f), innerLength - 1), 0))
        out_vectorlist.data[i].x = innerVectorList.data[bIndex].x * (1-influence) + innerVectorList.data[aIndex].x * influence
        out_vectorlist.data[i].y = innerVectorList.data[bIndex].y * (1-influence) + innerVectorList.data[aIndex].y * influence
        out_vectorlist.data[i].z = innerVectorList.data[bIndex].z * (1-influence) + innerVectorList.data[aIndex].z * influence
    return out_vectorlist

def inheritanceCurveEuler(EulerList eA, EulerList eB, EulerList splineEulers, DoubleList influences):
    cdef Py_ssize_t i, j, bIndex, aIndex
    cdef Py_ssize_t count = eA.getLength()
    cdef Py_ssize_t splineEulerCount = splineEulers.getLength()
    cdef Py_ssize_t innerLength = splineEulerCount + 2
    cdef double f, influence
    cdef EulerList outEulerlist = EulerList(length = count)
    cdef EulerList innerEulerList = EulerList(length = innerLength)
    for i in range(count):
        innerEulerList.data[0] = eA.data[i]
        for j in range(splineEulerCount):
            innerEulerList.data[j+1].x = splineEulers.data[j].x
            innerEulerList.data[j+1].y = splineEulers.data[j].y
            innerEulerList.data[j+1].z = splineEulers.data[j].z
        innerEulerList.data[innerLength - 1] = eB.data[i]
        f = influences.data[i] * (innerLength - 1)
        influence = f % 1 
        bIndex = int(max(min(floor(f), innerLength - 1), 0))
        aIndex = int(max(min(ceil(f), innerLength - 1), 0))
        outEulerlist.data[i].x = innerEulerList.data[bIndex].x * (1-influence) + innerEulerList.data[aIndex].x * influence
        outEulerlist.data[i].y = innerEulerList.data[bIndex].y * (1-influence) + innerEulerList.data[aIndex].y * influence
        outEulerlist.data[i].z = innerEulerList.data[bIndex].z * (1-influence) + innerEulerList.data[aIndex].z * influence
    return outEulerlist    

def inheritanceCurveMatrix(Matrix4x4List mA, Matrix4x4List mB, Vector3DList splinePoints, EulerList splineEulers, float randomScale, DoubleList influences, bint align):
    cdef Vector3DList tA = extractMatrixTranslations(mA)
    cdef Vector3DList tB = extractMatrixTranslations(mB)
    cdef EulerList rA = extractMatrixRotations(mA)
    cdef EulerList rB = extractMatrixRotations(mB)
    cdef Vector3DList sA = extractMatrixScales(mA)
    cdef Vector3DList sB = extractMatrixScales(mB)
    cdef int count = max(mA.getLength(), mB.getLength())
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(tA, (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(rA, (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(sA, (1, 1, 1))
    cdef Vector3DList translationCurve = inheritanceCurveVector(tA, tB, splinePoints, randomScale, influences)
    cdef EulerList rotationCurve = EulerList()
    if align:
        rotationCurve = inheritanceCurveEuler(rA, rB, splineEulers, influences)
    for i in range(count):
        translations_out.get(i).x = translationCurve.data[i].x
        translations_out.get(i).y = translationCurve.data[i].y
        translations_out.get(i).z = translationCurve.data[i].z
        if align:
            rotations_out.get(i).x = rotationCurve.data[i].x
            rotations_out.get(i).y = rotationCurve.data[i].y
            rotations_out.get(i).z = rotationCurve.data[i].z
        else:
            rotations_out.get(i).x = rA.data[i].x * (1-influences.data[i]) + rB.data[i].x * influences.data[i]
            rotations_out.get(i).y = rA.data[i].y * (1-influences.data[i]) + rB.data[i].y * influences.data[i]
            rotations_out.get(i).z = rA.data[i].z * (1-influences.data[i]) + rB.data[i].z * influences.data[i]    
        scales_out.get(i).x = sA.data[i].x * (1-influences.data[i]) + sB.data[i].x * influences.data[i]
        scales_out.get(i).y = sA.data[i].y * (1-influences.data[i]) + sB.data[i].y * influences.data[i]
        scales_out.get(i).z = sA.data[i].z * (1-influences.data[i]) + sB.data[i].z * influences.data[i]      
    return composeMatrices(count, translations_out, rotations_out, scales_out)

cdef vectorListADD(Vector3DList a, Vector3DList b):
    cdef Py_ssize_t i
    for i in range(a.getLength()):
        a.data[i].x += b.data[i].x
        a.data[i].y += b.data[i].y
        a.data[i].z += b.data[i].z
    return a 

#Curl reference: https://github.com/cabbibo/glsl-curl-noise
cdef evalNoise(Vector3DList vectors, str noiseType, str fractalType, str perturbType, int seed, 
                                int octaves, float amplitude, float frequency, scale, offset):
    cdef Py_ssize_t i
    cdef Py_ssize_t count = vectors.getLength()
    cdef FloatList x, y, z
    cdef Vector3DList vectors1 = Vector3DList(length = count)
    cdef Vector3DList vectors2 = Vector3DList(length = count)
    cdef Vector3DList out = Vector3DList(length = count)
    for i in range(count):
        vectors1.data[i].x = vectors.data[i].y - 19.1
        vectors1.data[i].y = vectors.data[i].z + 33.4
        vectors1.data[i].z = vectors.data[i].x + 47.2
        vectors2.data[i].x = vectors.data[i].z + 74.2
        vectors2.data[i].y = vectors.data[i].x - 124.5
        vectors2.data[i].z = vectors.data[i].y + 99.4
    noise = PyNoise()
    noise.setNoiseType(noiseType)
    noise.setFractalType(fractalType)
    noise.setPerturbType(perturbType)
    noise.setAmplitude(amplitude)
    noise.setFrequency(frequency)
    noise.setOffset(offset)
    noise.setSeed(seed)
    noise.setAxisScales((scale.x,scale.y,scale.z))
    noise.setOctaves(min(max(octaves, 1), 10))
    noise.setCellularJitter(0)
    x = noise.calculateList(vectors)
    y = noise.calculateList(vectors1)
    z = noise.calculateList(vectors2)
    i = 0
    for i in range(count):
        out.data[i].x = x.data[i]
        out.data[i].y = y.data[i]
        out.data[i].z = z.data[i]
    return out

@cython.cdivision(True)
def curlNoise(Vector3DList vectors, str noiseType, str fractalType, str perturbType, float epsilon, 
        Py_ssize_t seed, Py_ssize_t octaves, float amplitude, float frequency, scale, offset, bint normalize):
    cdef:
        Py_ssize_t i
        Py_ssize_t count = vectors.getLength()
        double divisor, modV
        Vector3DList x0 = Vector3DList(length = count)
        Vector3DList x1 = Vector3DList(length = count)
        Vector3DList y0 = Vector3DList(length = count)
        Vector3DList y1 = Vector3DList(length = count)
        Vector3DList z0 = Vector3DList(length = count)
        Vector3DList z1 = Vector3DList(length = count)
        Vector3DList pos_x0, pos_x1, pos_y0, pos_y1, pos_z0, pos_z1
        Vector3DList outnoise = Vector3DList(length = count)
    for i in range(count):
        x0.data[i].x = vectors.data[i].x - epsilon
        x0.data[i].y = vectors.data[i].y
        x0.data[i].z = vectors.data[i].z
        x1.data[i].x = vectors.data[i].x + epsilon
        x1.data[i].y = vectors.data[i].y
        x1.data[i].z = vectors.data[i].z
        y0.data[i].x = vectors.data[i].x 
        y0.data[i].y = vectors.data[i].y - epsilon
        y0.data[i].z = vectors.data[i].z
        y1.data[i].x = vectors.data[i].x 
        y1.data[i].y = vectors.data[i].y + epsilon
        y1.data[i].z = vectors.data[i].z
        z0.data[i].x = vectors.data[i].x 
        z0.data[i].y = vectors.data[i].y
        z0.data[i].z = vectors.data[i].z - epsilon
        z1.data[i].x = vectors.data[i].x 
        z1.data[i].y = vectors.data[i].y
        z1.data[i].z = vectors.data[i].z + epsilon
    pos_x0 = evalNoise(x0, noiseType, fractalType, perturbType, seed, octaves, amplitude, frequency, scale, offset)
    pos_x1 = evalNoise(x1, noiseType, fractalType, perturbType, seed, octaves, amplitude, frequency, scale, offset) 
    pos_y0 = evalNoise(y0, noiseType, fractalType, perturbType, seed, octaves, amplitude, frequency, scale, offset)
    pos_y1 = evalNoise(y1, noiseType, fractalType, perturbType, seed, octaves, amplitude, frequency, scale, offset)
    pos_z0 = evalNoise(z0, noiseType, fractalType, perturbType, seed, octaves, amplitude, frequency, scale, offset)
    pos_z1 = evalNoise(z1, noiseType, fractalType, perturbType, seed, octaves, amplitude, frequency, scale, offset)
    divisor = 1.0 /2.0 * epsilon
    i = 0
    for i in range(count):
        outnoise.data[i].x = (pos_y1.data[i].z - pos_y0.data[i].z - pos_z1.data[i].y + pos_z0.data[i].y) * divisor
        outnoise.data[i].y = (pos_z1.data[i].x - pos_z0.data[i].x - pos_x1.data[i].z + pos_x0.data[i].z) * divisor
        outnoise.data[i].z = (pos_x1.data[i].y - pos_x0.data[i].y - pos_y1.data[i].x + pos_y0.data[i].x) * divisor
        if normalize:
            modV = sqrt(outnoise.data[i].x * outnoise.data[i].x + outnoise.data[i].y * outnoise.data[i].y + outnoise.data[i].z * outnoise.data[i].z)
            outnoise.data[i].x /= modV
            outnoise.data[i].y /= modV
            outnoise.data[i].z /= modV
    return outnoise

def CurlEulerIntegrate(Vector3DList vectors, str noiseType, str fractalType, str perturbType, float epsilon, 
    Py_ssize_t seed, Py_ssize_t octaves, float amplitude, float frequency, scale, offset, bint normalize, Py_ssize_t iteration, bint fullList):
    cdef Py_ssize_t i
    cdef Vector3DList result
    cdef Vector3DList fullResult
    result = vectors
    fullResult = vectors
    for i in range(iteration):
        if i != 0:
            result = vectorListADD(curlNoise(result, noiseType, fractalType, perturbType, epsilon, 
                    seed, octaves, amplitude, frequency, scale, offset, normalize), result)
            if fullList:        
                fullResult.extend(result)
    if fullList:                           
        return fullResult
    else:
        return result    
               