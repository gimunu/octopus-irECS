#include <config.h>

#ifdef HAVE_CLAMDBLAS

#include <clBLAS.h>

void FC_FUNC_(clamdblasgetversion_low, CLAMDBLASGETVERSION_LOW)(int * major, int * minor, int * patch, int * status){
  cl_uint cl_major, cl_minor, cl_patch;

  *status = clblasGetVersion(&cl_major, &cl_minor, &cl_patch);
  *major = cl_major;
  *minor = cl_minor;
  *patch = cl_patch;
}

void FC_FUNC_(clamdblassetup_low, CLAMDBLASSETUP_LOW)(int * status){
  *status = clblasSetup();
}

void FC_FUNC_(clamdblasteardown_low, CLAMDBLASTEARDOWN_LOW)(){
  clblasTeardown();
}

void FC_FUNC_(clamdblasdtrsmex_low, CLAMDBLASDTRSMEX_LOW)(int * order,
							  int * side,
							  int * uplo,
							  int * transA,
							  int * diag,
							  cl_long * M,
							  cl_long * N,
							  double * alpha,
							  const cl_mem * A,
							  size_t * offA,
							  size_t * lda,
							  cl_mem * B,
							  size_t * offB,
							  size_t * ldb, 
							  cl_command_queue * CommandQueue, 
							  int * status){


  *status = clblasDtrsm((clblasOrder) *order, (clblasSide) *side, (clblasUplo) *uplo, 
			(clblasTranspose) *transA, (clblasDiag) *diag,
			(size_t) *M, (size_t) *N, *alpha, 
			*A, (size_t) *offA, (size_t) *lda, 
			*B, (size_t) *offB, (size_t) *ldb, 
			1, CommandQueue, 0, NULL, NULL);
}


void FC_FUNC_(clamdblasztrsmex_low, CLAMDBLASZTRSMEX_LOW)(int * order,
							  int * side,
							  int * uplo,
							  int * transA,
							  int * diag,
							  cl_long * M,
							  cl_long * N,
							  DoubleComplex * alpha,
							  const cl_mem * A,
							  size_t * offA,
							  size_t * lda,
							  cl_mem * B,
							  size_t * offB,
							  size_t * ldb, 
							  cl_command_queue * CommandQueue, 
							  int * status){


  *status = clblasZtrsm((clblasOrder) *order, (clblasSide) *side, (clblasUplo) *uplo, 
			(clblasTranspose) *transA, (clblasDiag) *diag,
			(size_t) *M, (size_t) *N, *alpha, 
			*A, (size_t) *offA, (size_t) *lda, 
			*B, (size_t) *offB, (size_t) *ldb, 
			1, CommandQueue, 0, NULL, NULL);
}

void FC_FUNC_(clamdblasdgemmex_low, CLAMDBLASDGEMMEX_LOW)(int * order,
							  int * transA, 
							  int * transB, 
							  cl_long * M,
							  cl_long * N,
							  cl_long * K,
							  double * alpha,
							  const cl_mem * A,
							  cl_long * offA,
							  cl_long * lda,
							  const cl_mem * B,
							  cl_long * offB,
							  cl_long * ldb, 
							  double * beta, 
							  cl_mem * C, 
							  cl_long * offC, 
							  cl_long * ldc, 
							  cl_command_queue * CommandQueue,
							  int * status){

  *status = clblasDgemm((clblasOrder) *order, (clblasTranspose) *transA, (clblasTranspose) *transB, 
			(size_t) *M, (size_t) *N, (size_t) *K, *alpha, 
			*A, (size_t) *offA, (size_t) *lda, 
			*B, (size_t) *offB, (size_t) *ldb, *beta, 
			*C, (size_t) *offC, (size_t) *ldc, 
			1, CommandQueue, 0, NULL, NULL);
}

void FC_FUNC_(clamdblaszgemmex_low, CLAMDBLASDGEMMEX_LOW)(int * order,
							  int * transA, 
							  int * transB, 
							  cl_long * M,
							  cl_long * N,
							  cl_long * K,
							  DoubleComplex * alpha,
							  const cl_mem * A,
							  cl_long * offA,
							  cl_long * lda,
							  const cl_mem * B,
							  cl_long * offB,
							  cl_long * ldb, 
							  DoubleComplex * beta, 
							  cl_mem * C, 
							  cl_long * offC, 
							  cl_long * ldc, 
							  cl_command_queue * CommandQueue,
							  int * status){

  *status = clblasZgemm((clblasOrder) *order, (clblasTranspose) *transA, (clblasTranspose) *transB, 
			(size_t) *M, (size_t) *N, (size_t) *K, *alpha, 
			*A, (size_t) *offA, (size_t) *lda, 
			*B, (size_t) *offB, (size_t) *ldb, *beta, 
			*C, (size_t) *offC, (size_t) *ldc, 
			1, CommandQueue, 0, NULL, NULL);
}

void FC_FUNC_(clamdblasdsyrkex_low, CLAMDBLASDSYRKEX_LOW)(int * order,
							  int * uplo, 
							  int * transA, 
							  cl_long * N,
							  cl_long * K,
							  double * alpha,
							  const cl_mem * A,
							  cl_long * offA,
							  cl_long * lda,
							  double * beta, 
							  cl_mem * C, 
							  cl_long * offC, 
							  cl_long * ldc, 
							  cl_command_queue * CommandQueue,
							  int * status){

  *status = clblasDsyrk((clblasOrder) *order, (clblasUplo) *uplo, (clblasTranspose) *transA, 
			(size_t) *N, (size_t) *K, *alpha, 
			*A, (size_t) *offA, (size_t) *lda, *beta, 
			*C, (size_t) *offC, (size_t) *ldc, 
			1, CommandQueue, 0, NULL, NULL);
}

void FC_FUNC_(clamdblaszherkex_low, CLAMDBLASZHERKEX_LOW)(int * order,
							  int * uplo, 
							  int * transA, 
							  cl_long * N,
							  cl_long * K,
							  double * alpha,
							  const cl_mem * A,
							  cl_long * offA,
							  cl_long * lda,
							  double * beta, 
							  cl_mem * C, 
							  cl_long * offC, 
							  cl_long * ldc, 
							  cl_command_queue * CommandQueue,
							  int * status){

  *status = clblasZherk((clblasOrder) *order, (clblasUplo) *uplo, (clblasTranspose) *transA, 
			(size_t) *N, (size_t) *K, *alpha, 
			*A, (size_t) *offA, (size_t) *lda, *beta, 
			*C, (size_t) *offC, (size_t) *ldc, 
			1, CommandQueue, 0, NULL, NULL);
}

#endif
