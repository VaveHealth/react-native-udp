#include <jni.h>
#include <sys/types.h>
#include "pthread.h"
#include <jsi/jsi.h>
#include "../cpp/utils/TypedArray.h"

using namespace facebook::jsi;

JavaVM *java_vm;
jclass java_class;
jobject java_object;

typedef u_int8_t byte;

/**
 * A simple callback function that allows us to detach current JNI Environment
 * when the thread
 * See https://stackoverflow.com/a/30026231 for detailed explanation
 */

void DeferThreadDetach(JNIEnv *env) {
    static pthread_key_t thread_key;

    // Set up a Thread Specific Data key, and a callback that
    // will be executed when a thread is destroyed.
    // This is only done once, across all threads, and the value
    // associated with the key for any given thread will initially
    // be NULL.
    static auto run_once = [] {
        const auto err = pthread_key_create(&thread_key, [](void *ts_env) {
            if (ts_env) {
                java_vm->DetachCurrentThread();
            }
        });
        if (err) {
            // Failed to create TSD key. Throw an exception if you want to.
        }
        return 0;
    }();

    // For the callback to actually be executed when a thread exits
    // we need to associate a non-NULL value with the key on that thread.
    // We can use the JNIEnv* as that value.
    const auto ts_env = pthread_getspecific(thread_key);
    if (!ts_env) {
        if (pthread_setspecific(thread_key, env)) {
            // Failed to set thread-specific value for key. Throw an exception if you want to.
        }
    }
}

/**
 * Get a JNIEnv* valid for this thread, regardless of whether
 * we're on a native thread or a Java thread.
 * If the calling thread is not currently attached to the JVM
 * it will be attached, and then automatically detached when the
 * thread is destroyed.
 *
 * See https://stackoverflow.com/a/30026231 for detailed explanation
 */
JNIEnv *GetJniEnv() {
    JNIEnv *env = nullptr;
    // We still call GetEnv first to detect if the thread already
    // is attached. This is done to avoid setting up a DetachCurrentThread
    // call on a Java thread.

    // g_vm is a global.
    auto get_env_result = java_vm->GetEnv((void **) &env, JNI_VERSION_1_6);
    if (get_env_result == JNI_EDETACHED) {
        if (java_vm->AttachCurrentThread(&env, NULL) == JNI_OK) {
            DeferThreadDetach(env);
        } else {
            // Failed to attach thread. Throw an exception if you want to.
        }
    } else if (get_env_result == JNI_EVERSION) {
        // Unsupported JNI version. Throw an exception if you want to.
    }
    return env;
}

void install(facebook::jsi::Runtime &jsiRuntime) {
    auto JSI_RN_UDP_getFrameDataByFrameNo = Function::createFromHostFunction(jsiRuntime,
                                                          PropNameID::forAscii(jsiRuntime,
                                                                               "JSI_RN_UDP_getFrameDataByFrameNo"),
                                                          1,
                                                          [](Runtime &runtime,
                                                             const Value &thisValue,
                                                             const Value *arguments,
                                                             size_t count) -> Value {

                                                              JNIEnv *jniEnv = GetJniEnv();

                                                              java_class = jniEnv->GetObjectClass(
                                                                          java_object);

                                                              int key = arguments[0].getNumber();

                                                              jmethodID byteBufferMethodId = jniEnv->GetMethodID(
                                                                      java_class, "getFrameDataByFrameNo", "(I)[B");

                                                              jbyteArray byteArray = (jbyteArray)jniEnv->CallObjectMethod(
                                                                          java_object,
                                                                          byteBufferMethodId, key);

                                                              auto length = (size_t) jniEnv->GetArrayLength(byteArray);

                                                              jbyte* elements = jniEnv->GetByteArrayElements(byteArray, nullptr);

                                                              auto typedArray = TypedArray<TypedArrayKind::Uint8Array>(runtime, length);
                                                              auto arrayBuffer = typedArray.getBuffer(runtime);
                                                              memcpy(arrayBuffer.data(runtime), reinterpret_cast<byte*>(elements), length);
                                                              jniEnv->ReleaseByteArrayElements(byteArray, elements, JNI_ABORT);
                                                              return typedArray;
                                                          });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getFrameDataByFrameNo", std::move(JSI_RN_UDP_getFrameDataByFrameNo));

    auto JSI_RN_UDP_getFirstMemorisedFrameNo = Function::createFromHostFunction(jsiRuntime,
                                                             PropNameID::forAscii(jsiRuntime,
                                                                                  "JSI_RN_UDP_getFirstMemorisedFrameNo"),
                                                             0,
                                                             [](Runtime &runtime,
                                                                const Value &thisValue,
                                                                const Value *arguments,
                                                                size_t count) -> Value {

                                                                 JNIEnv *jniEnv = GetJniEnv();

                                                                 java_class = jniEnv->GetObjectClass(
                                                                         java_object);

                                                                 jmethodID methodId = jniEnv->GetMethodID(
                                                                         java_class, "getFirstMemorisedFrameNo", "()I");

                                                                 auto key = jniEnv->CallIntMethod(
                                                                         java_object,
                                                                         methodId);

                                                                 return Value(key);
                                                             });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getFirstMemorisedFrameNo", std::move(JSI_RN_UDP_getFirstMemorisedFrameNo));

    auto JSI_RN_UDP_getLastMemorisedFrameNo = Function::createFromHostFunction(jsiRuntime,
                                                              PropNameID::forAscii(jsiRuntime,
                                                                                   "JSI_RN_UDP_getLastMemorisedFrameNo"),
                                                              0,
                                                              [](Runtime &runtime,
                                                                 const Value &thisValue,
                                                                 const Value *arguments,
                                                                 size_t count) -> Value {

                                                                  JNIEnv *jniEnv = GetJniEnv();

                                                                  java_class = jniEnv->GetObjectClass(
                                                                          java_object);

                                                                  jmethodID methodId = jniEnv->GetMethodID(
                                                                          java_class, "getLastMemorisedFrameNo", "()I");

                                                                  auto key = jniEnv->CallIntMethod(
                                                                          java_object,
                                                                          methodId);

                                                                  return Value(key);
                                                              });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getLastMemorisedFrameNo", std::move(JSI_RN_UDP_getLastMemorisedFrameNo));

    auto JSI_RN_UDP_getCountOfMemorisedFrames = Function::createFromHostFunction(jsiRuntime,
                                                             PropNameID::forAscii(jsiRuntime,
                                                                                  "JSI_RN_UDP_getCountOfMemorisedFrames"),
                                                             0,
                                                             [](Runtime &runtime,
                                                                const Value &thisValue,
                                                                const Value *arguments,
                                                                size_t count) -> Value {

                                                                 JNIEnv *jniEnv = GetJniEnv();

                                                                 java_class = jniEnv->GetObjectClass(
                                                                         java_object);

                                                                 jmethodID methodId = jniEnv->GetMethodID(
                                                                         java_class, "getCountOfMemorisedFrames", "()I");

                                                                 auto key = jniEnv->CallIntMethod(
                                                                         java_object,
                                                                         methodId);

                                                                 return Value(key);
                                                             });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getCountOfMemorisedFrames", std::move(JSI_RN_UDP_getCountOfMemorisedFrames));

    auto JSI_RN_UDP_getMaxNumberOfMemorisedFrames = Function::createFromHostFunction(jsiRuntime,
                                                                                 PropNameID::forAscii(jsiRuntime,
                                                                                                      "JSI_RN_UDP_getMaxNumberOfMemorisedFrames"),
                                                                                 0,
                                                                                 [](Runtime &runtime,
                                                                                    const Value &thisValue,
                                                                                    const Value *arguments,
                                                                                    size_t count) -> Value {

                                                                                     JNIEnv *jniEnv = GetJniEnv();

                                                                                     java_class = jniEnv->GetObjectClass(
                                                                                             java_object);

                                                                                     jmethodID methodId = jniEnv->GetMethodID(
                                                                                             java_class, "getMaxNumberOfMemorisedFrames", "()I");

                                                                                     auto maxNumberOfFrames = jniEnv->CallIntMethod(
                                                                                             java_object,
                                                                                             methodId);

                                                                                     return Value(maxNumberOfFrames);
                                                                                 });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getMaxNumberOfMemorisedFrames", std::move(JSI_RN_UDP_getMaxNumberOfMemorisedFrames));

    auto JSI_RN_UDP_setMaxNumberOfMemorisedFrames = Function::createFromHostFunction(jsiRuntime,
                                                                                     PropNameID::forAscii(jsiRuntime,
                                                                                                          "JSI_RN_UDP_setMaxNumberOfMemorisedFrames"),
                                                                                     1,
                                                                                     [](Runtime &runtime,
                                                                                        const Value &thisValue,
                                                                                        const Value *arguments,
                                                                                        size_t count) -> Value {

                                                                                         JNIEnv *jniEnv = GetJniEnv();

                                                                                         java_class = jniEnv->GetObjectClass(
                                                                                                 java_object);

                                                                                         jmethodID methodId = jniEnv->GetMethodID(
                                                                                                 java_class, "setMaxNumberOfMemorisedFrames", "(I)V");

                                                                                         int maxNumberOfFrames = arguments[0].getNumber();

                                                                                         jniEnv->CallVoidMethod(
                                                                                                 java_object,
                                                                                                 methodId, maxNumberOfFrames);

                                                                                         return Value::undefined();
                                                                                     });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_setMaxNumberOfMemorisedFrames", std::move(JSI_RN_UDP_setMaxNumberOfMemorisedFrames));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_tradle_react_UdpSockets_nativeInstall(JNIEnv *env, jobject thiz, jlong jsi,
                                               jstring doc_dir) {

    auto runtime = reinterpret_cast<facebook::jsi::Runtime *>(jsi);

    if (runtime) {
        install(*runtime);
    }

    env->GetJavaVM(&java_vm);
    java_object = env->NewGlobalRef(thiz);
}
