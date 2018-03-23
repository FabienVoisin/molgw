!=========================================================================
! This file is part of MOLGW.
! Author: Fabien Bruneval
!
! This file contains
! the procedures for input and outputs
!
!=========================================================================
subroutine header()
#ifdef FORTRAN2008
 use,intrinsic :: iso_fortran_env, only: compiler_version,compiler_options
#endif
 use m_definitions
 use m_mpi
 use m_warning,only: issue_warning
 use m_tools,only: orbital_momentum_name
 use m_libint_tools,only: libint_init
 implicit none

#ifdef _OPENMP
 integer,external  :: OMP_get_max_threads
 character(len=64) :: msg
#endif
 character(len=40)   :: git_sha
 integer             :: values(8)
#ifdef FORTRAN2008
 integer             :: nchar,kchar,lchar
 character(len=1024) :: chartmp
#endif
!=====
! variables used to call C
 integer(C_INT)      :: ammax
 logical(C_BOOL)     :: has_onebody,has_gradient
!=====

! Here we call the fortran code that was generated by the python script
! Any new variable should be added through the python script
#include "git_sha.f90"

!=====

 write(stdout,'(1x,70("="))')
 write(stdout,'(/,/,12x,a,/)') 'Welcome to the fascinating world of MOLGW'
 write(stdout,'(24x,a)')       'version 1.F'
 write(stdout,'(/,/,1x,70("="))')

 write(stdout,'(/,a,a,/)') ' MOLGW commit git SHA: ',git_sha
#ifdef FORTRAN2008
 write(stdout,'(1x,a,a)')    'compiled with ',compiler_version()
 write(stdout,'(1x,a)')      'with options: '
 chartmp = compiler_options()
 nchar = LEN(TRIM(chartmp))
 kchar = 1
 lchar = 0
 do
   lchar = SCAN(chartmp(kchar:nchar),' ')
   if( lchar == 0 ) exit
   write(stdout,'(6x,a,a)') 'FCOPT  ',chartmp(kchar:kchar+lchar-1)
   kchar = kchar + lchar
 enddo
 write(stdout,*)
#endif


 call date_and_time(VALUES=values)

 write(stdout,'(a,i2.2,a,i2.2,a,i4.4)') ' Today is ',values(2),'/',values(3),'/',values(1)
 write(stdout,'(a,i2.2,a,i2.2)')        ' It is now ',values(5),':',values(6)
 select case(values(5))
 case(03,04,05,06,07)
   write(stdout,*) 'And it is too early to work. Go back to sleep'
 case(22,23,00,01,02)
   write(stdout,*) 'And it is too late to work. Go to bed and have a sleep'
 case(12,13)
   write(stdout,*) 'Go and get some good food'
 case(17)
   write(stdout,*) 'Dont forget to go and get the kids'
 case default
   write(stdout,*) 'And it is perfect time to work'
 end select


 write(stdout,'(/,1x,a)') 'Linking options:'
#ifdef HAVE_LIBXC
!#ifndef LIBXC_SVN
! call xc_f90_version(values(1),values(2))
! write(chartmp,'(i2,a,i2)') values(1),'.',values(2)
!#else
! call xc_f90_version(values(1),values(2),values(3))
! write(chartmp,'(i2,a,i2,a,i2)') values(1),'.',values(2),'.',values(3)
!#endif
! write(stdout,*) 'LIBXC version '//TRIM(chartmp)
 write(stdout,*) 'Running with LIBXC'
#endif
#ifdef _OPENMP
 write(msg,'(i6)') OMP_get_max_threads()
 msg='OPENMP option is activated with threads number'//msg
 call issue_warning(msg)
#endif
#if defined HAVE_MPI && defined HAVE_SCALAPACK
 write(stdout,*) 'Running with MPI'
 write(stdout,*) 'Running with SCALAPACK'
#endif
#if defined(HAVE_MPI) && !defined(HAVE_SCALAPACK)
 call die('Code compiled with SCALAPACK, but without MPI. This is not permitted')
#endif
#if !defined(HAVE_MPI) && defined(HAVE_SCALAPACK)
 call die('Code compiled with MPI, but without SCALAPACK. This is not permitted')
#endif

 ! LIBINT details
 call libint_init(ammax,has_onebody,has_gradient)
 write(stdout,'(1x,a)')        'Running with LIBINT (to calculate the Coulomb integrals)'
 write(stdout,'(6x,a,i5,3x,a)') 'max angular momentum handled by your LIBINT compilation: ', &
                                ammax,orbital_momentum_name(ammax)
 call set_molgw_lmax(ammax)

#ifdef HAVE_LIBINT_ONEBODY
 if( .NOT. has_onebody ) &
   call die('MOLGW compiled with LIBINT one-body terms, however the LIBINT compilation does not calculate the one-body terms')
 if( .NOT. has_gradient ) &
   call die('LIBINT compilation does not have the first derivative')
 write(stdout,'(1x,a)') 'Using LIBINT for the one-body parts of the Hamiltonian as well'
#endif
 write(stdout,*)
 write(stdout,*)


end subroutine header


!=========================================================================
subroutine dump_out_occupation(title,nstate,nspin,occupation)
 use m_definitions
 use m_mpi
 implicit none
 character(len=*),intent(in) :: title
 integer,intent(in)          :: nstate,nspin
 real(dp),intent(in)         :: occupation(nstate,nspin)
!=====
 integer :: ihomo
 integer :: istate
!=====

 write(stdout,'(/,1x,a)') TRIM(title)

 if( nspin == 2 ) then
   write(stdout,'(a)') '           spin 1       spin 2 '
 endif
 do istate=1,nstate
   if( ANY(occupation(istate,:) > 0.001_dp) ) ihomo = istate
 enddo

 do istate=MAX(1,ihomo-5),MIN(ihomo+5,nstate)
   write(stdout,'(1x,i3,2(2(1x,f12.5)),2x)') istate,occupation(istate,:)
 enddo
 write(stdout,*)

end subroutine dump_out_occupation


!=========================================================================
subroutine dump_out_energy(title,nstate,nspin,occupation,energy)
 use m_definitions
 use m_mpi
 use m_inputparam,only: spin_fact
 implicit none
 character(len=*),intent(in) :: title
 integer,intent(in)          :: nstate,nspin
 real(dp),intent(in)         :: occupation(nstate,nspin),energy(nstate,nspin)
!=====
 integer,parameter :: MAXSIZE=300
!=====
 integer  :: istate
!=====


 write(stdout,'(/,1x,a)') TRIM(title)

 if(nspin==1) then
   write(stdout,'(a)') '   #       (Ha)         (eV)      '
 else
   write(stdout,'(a)') '   #              (Ha)                      (eV)      '
   write(stdout,'(a)') '           spin 1       spin 2       spin 1       spin 2'
 endif
 do istate=1,MIN(nstate,MAXSIZE)
   select case(nspin)
   case(1)
     write(stdout,'(1x,i3,2(1x,f12.5),4x,f8.4)') istate,energy(istate,:),energy(istate,:)*Ha_eV,occupation(istate,:)
   case(2)
     write(stdout,'(1x,i3,2(2(1x,f12.5)),4x,2(f8.4,2x))') istate,energy(istate,:),energy(istate,:)*Ha_eV,occupation(istate,:)
   end select
   if(istate < nstate) then
     if( ANY( occupation(istate+1,:) < spin_fact/2.0_dp .AND. occupation(istate,:) > spin_fact/2.0_dp ) ) then
        if(nspin==1) then
          write(stdout,'(a)') '  -----------------------------'
        else
          write(stdout,'(a)') '  -------------------------------------------------------'
        endif
     endif
   endif
 enddo

 write(stdout,*)

end subroutine dump_out_energy


!=========================================================================
subroutine dump_out_matrix(print_matrix,title,n,nspin,matrix)
 use m_definitions
 use m_mpi
 implicit none
 logical,intent(in)          :: print_matrix
 character(len=*),intent(in) :: title
 integer,intent(in)          :: n,nspin
 real(dp),intent(in)         :: matrix(n,n,nspin)
!=====
 integer,parameter :: MAXSIZE=25
!=====
 integer :: i,ispin
!=====

 if( .NOT. print_matrix ) return

 write(stdout,'(/,1x,a)') TRIM(title)

 do ispin=1,nspin
   if(nspin==2) then
     write(stdout,'(a,i1)') ' spin polarization # ',ispin
   endif
   do i=1,MIN(n,MAXSIZE)
     write(stdout,'(1x,i3,100(1x,f12.5))') i,matrix(i,1:MIN(n,MAXSIZE),ispin)
   enddo
   write(stdout,*)
 enddo
 write(stdout,*)

end subroutine dump_out_matrix


!=========================================================================
subroutine output_new_homolumo(calculation_name,nstate,occupation,energy,istate_min,istate_max)
 use m_definitions
 use m_mpi
 use m_inputparam,only: nspin,spin_fact
 implicit none

 character(len=*),intent(in) :: calculation_name
 integer,intent(in)          :: nstate,istate_min,istate_max
 real(dp),intent(in)         :: occupation(nstate,nspin),energy(nstate,nspin)
!=====
 real(dp) :: ehomo_tmp,elumo_tmp
 real(dp) :: ehomo(nspin),elumo(nspin)
 integer  :: ispin,istate
!=====

 do ispin=1,nspin
   ehomo_tmp=-HUGE(1.0_dp)
   elumo_tmp= HUGE(1.0_dp)

   do istate=istate_min,istate_max

     if( occupation(istate,ispin)/spin_fact > completely_empty ) then
       ehomo_tmp = MAX( ehomo_tmp , energy(istate,ispin) )
     endif

     if( occupation(istate,ispin)/spin_fact < 1.0_dp - completely_empty ) then
       elumo_tmp = MIN( elumo_tmp , energy(istate,ispin) )
     endif

   enddo

   ehomo(ispin) = ehomo_tmp
   elumo(ispin) = elumo_tmp

 enddo


 write(stdout,*)
 if( ALL( ehomo(:) > -1.0e6 ) ) then
   write(stdout,'(1x,a,1x,a,2(3x,f12.6))') TRIM(calculation_name),'HOMO energy    (eV):',ehomo(:) * Ha_eV
 endif
 if( ALL( elumo(:) <  1.0e6 ) ) then
   write(stdout,'(1x,a,1x,a,2(3x,f12.6))') TRIM(calculation_name),'LUMO energy    (eV):',elumo(:) * Ha_eV
 endif
 if( ALL( ehomo(:) > -1.0e6 ) .AND. ALL( elumo(:) <  1.0e6 ) ) then
   write(stdout,'(1x,a,1x,a,2(3x,f12.6))') TRIM(calculation_name),'HOMO-LUMO gap  (eV):',( elumo(:)-ehomo(:) ) * Ha_eV
 endif
 write(stdout,*)


end subroutine output_new_homolumo


!=========================================================================
subroutine mulliken_pdos(nstate,basis,s_matrix,c_matrix,occupation,energy)
 use m_definitions
 use m_mpi
 use m_inputparam, only: nspin
 use m_atoms
 use m_basis_set
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: s_matrix(basis%nbf,basis%nbf)
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
 real(dp),intent(in)        :: occupation(nstate,nspin),energy(nstate,nspin)
!=====
 integer                    :: ibf,li,ibf1,ibf2,ishell
 integer                    :: natom1,natom2,istate,ispin
 logical                    :: file_exists
 integer                    :: pdosfile
 real(dp)                   :: proj_state_i(0:basis%ammax),proj_charge
 real(dp)                   :: cs_vector_i(basis%nbf)
 integer                    :: iatom_ibf(basis%nbf)
 integer                    :: li_ibf(basis%nbf)
!=====

 write(stdout,*)
 write(stdout,*) 'Projecting wavefunctions on selected atoms'
 inquire(file='manual_pdos',exist=file_exists)
 if(file_exists) then
   write(stdout,*) 'Opening file:','manual_pdos'
   open(newunit=pdosfile,file='manual_pdos',status='old')
   read(pdosfile,*) natom1,natom2
   close(pdosfile)
 else
   natom1=1
   natom2=1
 endif
 write(stdout,'(1x,a,i5,2x,i5)') 'Range of atoms considered: ',natom1,natom2

 do ishell=1,basis%nshell
   ibf1    = basis%shell(ishell)%istart
   ibf2    = basis%shell(ishell)%iend

   iatom_ibf(ibf1:ibf2) = basis%shell(ishell)%iatom
   li_ibf(ibf1:ibf2)    = basis%shell(ishell)%am
 enddo


 write(stdout,'(1x,a)') '==========================================='
 write(stdout,'(1x,a)') 'spin state  energy(eV)  Mulliken proj. total        proj s         proj p      proj d ... '
 proj_charge = 0.0_dp
 do ispin=1,nspin
   do istate=1,nstate
     proj_state_i(:) = 0.0_dp

     cs_vector_i(:) = MATMUL( c_matrix(:,istate,ispin) , s_matrix(:,:) )

     do ibf=1,basis%nbf
       if( iatom_ibf(ibf) >= natom1 .AND. iatom_ibf(ibf) <= natom2 ) then
         li = li_ibf(ibf)
         proj_state_i(li) = proj_state_i(li) + c_matrix(ibf,istate,ispin) * cs_vector_i(ibf)
       endif
     enddo
     proj_charge = proj_charge + occupation(istate,ispin) * SUM(proj_state_i(:))

     write(stdout,'(i3,1x,i5,1x,20(f16.6,4x))') ispin,istate,energy(istate,ispin) * Ha_eV,&
          SUM(proj_state_i(:)),proj_state_i(:)
   enddo
 enddo
 write(stdout,'(1x,a)') '==========================================='
 write(stdout,'(1x,a,f12.6)') 'Total Mulliken charge: ',proj_charge


end subroutine mulliken_pdos


!=========================================================================
subroutine plot_wfn(nstate,basis,c_matrix)
 use m_definitions
 use m_mpi
 use m_inputparam, only: nspin
 use m_atoms
 use m_cart_to_pure
 use m_basis_set
 use m_dft_grid,only: calculate_basis_functions_r
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
!=====
 integer,parameter          :: nr=2000
 real(dp),parameter         :: length=10.0_dp
 integer                    :: gt
 integer                    :: ir
 integer                    :: istate1,istate2,istate,ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:),phase(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xxmin,xxmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: wfrfile
!=====

 if( .NOT. is_iomaster ) return

 gt = get_gaussian_type_tag(basis%gaussian_type)

 write(stdout,'(/,1x,a)') 'Plotting some selected wavefunctions'
 inquire(file='manual_plotwfn',exist=file_exists)
 if(file_exists) then
   open(newunit=wfrfile,file='manual_plotwfn',status='old')
   read(wfrfile,*) istate1,istate2
   read(wfrfile,*) u(:)
   read(wfrfile,*) a(:)
   close(wfrfile)
 else
   istate1=1
   istate2=2
   u(:)=0.0_dp
   u(1)=1.0_dp
   a(:)=0.0_dp
 endif
 u(:) = u(:) / SQRT(SUM(u(:)**2))
 allocate(phase(istate1:istate2,nspin),phi(istate1:istate2,nspin))
 write(stdout,'(a,2(2x,i4))')   ' states:   ',istate1,istate2
 write(stdout,'(a,3(2x,f8.3))') ' direction:',u(:)
 write(stdout,'(a,3(2x,f8.3))') ' origin:   ',a(:)

 xxmin = MINVAL( u(1)*xbasis(1,:) + u(2)*xbasis(2,:) + u(3)*xbasis(3,:) ) - length
 xxmax = MAXVAL( u(1)*xbasis(1,:) + u(2)*xbasis(2,:) + u(3)*xbasis(3,:) ) + length

 phase(:,:)=1.0_dp

 do ir=1,nr
   rr(:) = ( xxmin + (ir-1)*(xxmax-xxmin)/REAL(nr-1,dp) ) * u(:) + a(:)


   call calculate_basis_functions_r(basis,rr,basis_function_r)

   do ispin=1,nspin
     phi(istate1:istate2,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )
   enddo

   !
   ! turn the wfns so that they are all positive at a given point
   if(ir==1) then
     do ispin=1,nspin
       do istate=istate1,istate2
         if( phi(istate,ispin) < 0.0_dp ) phase(istate,ispin) = -1.0_dp
       enddo
     enddo
   endif

   write(101,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),phi(:,:)*phase(:,:)
   write(102,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),phi(:,:)**2

 enddo

 deallocate(phase,phi)

end subroutine plot_wfn


!=========================================================================
subroutine plot_rho(nstate,basis,occupation,c_matrix)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_cart_to_pure
 use m_inputparam, only: nspin
 use m_basis_set
 use m_dft_grid,only: calculate_basis_functions_r
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(nstate,nspin)
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
!=====
 integer,parameter          :: nr=5000
 real(dp),parameter         :: length=4.0_dp
 integer                    :: gt
 integer                    :: ir
 integer                    :: ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xxmin,xxmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: rhorfile
!=====

 if( .NOT. is_iomaster ) return

 write(stdout,'(/,1x,a)') 'Plotting the density'

 gt = get_gaussian_type_tag(basis%gaussian_type)

 inquire(file='manual_plotrho',exist=file_exists)
 if(file_exists) then
   open(newunit=rhorfile,file='manual_plotrho',status='old')
   read(rhorfile,*) u(:)
   read(rhorfile,*) a(:)
   close(rhorfile)
 else
   u(:)=0.0_dp
   u(1)=1.0_dp
   a(:)=0.0_dp
 endif
 u(:) = u(:) / NORM2(u)
 allocate(phi(nstate,nspin))
 write(stdout,'(a,3(2x,f8.3))') ' direction:',u(:)
 write(stdout,'(a,3(2x,f8.3))') ' origin:   ',a(:)

 xxmin = MINVAL( u(1)*xbasis(1,:) + u(2)*xbasis(2,:) + u(3)*xbasis(3,:) ) - length
 xxmax = MAXVAL( u(1)*xbasis(1,:) + u(2)*xbasis(2,:) + u(3)*xbasis(3,:) ) + length


 do ir=1,nr
   rr(:) = ( xxmin + (ir-1)*(xxmax-xxmin)/REAL(nr-1,dp) ) * u(:) + a(:)


   call calculate_basis_functions_r(basis,rr,basis_function_r)

   do ispin=1,nspin
     phi(:,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,:,ispin) )
   enddo

   write(103,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),SUM( phi(:,:)**2 * occupation(:,:) )

   write(104,'(50(e16.8,2x))') NORM2(rr(:)),SUM( phi(:,:)**2 * occupation(:,:) ) * 4.0_dp * pi * NORM2(rr(:))**2
!   write(105,'(50(e16.8,2x))') NORM2(rr(:)),SUM( phi(1,:)**2 * occupation(1,:) ) * 4.0_dp * pi * NORM2(rr(:))**2
!   write(106,'(50(e16.8,2x))') NORM2(rr(:)),SUM( phi(2:,:)**2 * occupation(2:,:) ) * 4.0_dp * pi * NORM2(rr(:))**2

 enddo

 deallocate(phi)

end subroutine plot_rho


!=========================================================================
subroutine plot_rho_list(nstate,basis,occupation,c_matrix)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_cart_to_pure
 use m_inputparam, only: nspin
 use m_basis_set
 use m_dft_grid,only: calculate_basis_functions_r
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(nstate,nspin)
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
!=====
 integer                    :: gt
 integer                    :: ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xxmin,xxmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: rhorfile
 integer                    :: ix,iy,iz
 integer,parameter          :: nx=75 ! 87
 integer,parameter          :: ny=75 ! 91
 integer,parameter          :: nz=90 ! 65
 real(dp),parameter         :: dx = 0.174913 ! 0.204034
 real(dp)                   :: rr0(3)
 integer                    :: unitfile
!=====

 if( .NOT. is_iomaster ) return

 write(stdout,'(/,1x,a)') 'Plotting the density'

 gt = get_gaussian_type_tag(basis%gaussian_type)

 inquire(file='manual_plotrho',exist=file_exists)
 if(file_exists) then
   open(newunit=rhorfile,file='manual_plotrho',status='old')
   close(rhorfile)
 else
 endif
 allocate(phi(nstate,nspin))

 rr0(1) = -6.512752 ! -8.790885
 rr0(2) = -6.512752 ! -9.143313
 rr0(3) = -7.775444 ! -6.512752

 open(newunit=unitfile,file='rho.dat',action='WRITE')
 do ix=1,nx
 do iy=1,ny
 do iz=1,nz
   rr(1) = ix-1
   rr(2) = iy-1
   rr(3) = iz-1
   rr(:) = rr0(:) + rr(:) * dx


   call calculate_basis_functions_r(basis,rr,basis_function_r)

   do ispin=1,nspin
     phi(:,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,:,ispin) )
   enddo

   write(unitfile,'(1x,e16.8)') SUM( phi(3:,:)**2 * occupation(3:,:) )

 enddo
 enddo
 enddo
 close(unitfile)

 deallocate(phi)

end subroutine plot_rho_list


!=========================================================================
subroutine plot_cube_wfn(nstate,basis,occupation,c_matrix)
 use m_definitions
 use m_mpi
 use m_inputparam, only: nspin
 use m_cart_to_pure
 use m_atoms
 use m_basis_set
 use m_dft_grid,only: calculate_basis_functions_r
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(nstate,nspin)
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
!=====
 integer                    :: gt
 integer                    :: nx,ny,nz
 real(dp),parameter         :: length=3.499470_dp
 integer                    :: istate1,istate2,istate,ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xmin,xmax,ymin,ymax,zmin,zmax
 real(dp)                   :: dx,dy,dz
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: ix,iy,iz,iatom
 integer,allocatable        :: ocubefile(:,:)
 integer                    :: ocuberho(nspin)
 character(len=200)         :: file_name
 integer                    :: icubefile
!=====

 if( .NOT. is_iomaster ) return

 write(stdout,'(/,1x,a)') 'Plotting some selected wavefunctions in a cube file'

 gt = get_gaussian_type_tag(basis%gaussian_type)

 inquire(file='manual_cubewfn',exist=file_exists)
 if(file_exists) then
   open(newunit=icubefile,file='manual_cubewfn',status='old')
   read(icubefile,*) istate1,istate2
   read(icubefile,*) nx,ny,nz
   close(icubefile)
 else
   istate1=1
   istate2=2
   nx=40
   ny=40
   nz=40
 endif
 allocate(phi(istate1:istate2,nspin))
 write(stdout,'(a,2(2x,i4))')   ' states:   ',istate1,istate2

 xmin = MINVAL( xbasis(1,:) ) - length
 xmax = MAXVAL( xbasis(1,:) ) + length
 ymin = MINVAL( xbasis(2,:) ) - length
 ymax = MAXVAL( xbasis(2,:) ) + length
 zmin = MINVAL( xbasis(3,:) ) - length
 zmax = MAXVAL( xbasis(3,:) ) + length
 dx = (xmax-xmin)/REAL(nx,dp)
 dy = (ymax-ymin)/REAL(ny,dp)
 dz = (zmax-zmin)/REAL(nz,dp)
! xmin = -15.001591d0
! ymin = -15.001591d0
! zmin = -17.037892d0
! dx = 0.262502_dp
! dy = 0.262502_dp
! dz = 0.262502_dp

 allocate(ocubefile(istate1:istate2,nspin))

 do istate=istate1,istate2
   do ispin=1,nspin
     write(file_name,'(a,i3.3,a,i1,a)') 'wfn_',istate,'_',ispin,'.cube'
     open(newunit=ocubefile(istate,ispin),file=file_name)
     write(ocubefile(istate,ispin),'(a)') 'cube file generated from MOLGW'
     write(ocubefile(istate,ispin),'(a,i4)') 'wavefunction ',istate1
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') natom,xmin,ymin,zmin
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') nx,dx,0.,0.
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') ny,0.,dy,0.
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') nz,0.,0.,dz
     do iatom=1,natom
       write(ocubefile(istate,ispin),'(i6,4(2x,f12.6))') NINT(zatom(iatom)),0.0,xatom(:,iatom)
     enddo
   enddo
 enddo

 !
 ! check whether istate1:istate2 spans all the occupied states
 if( ALL( occupation(istate2+1,:) < completely_empty ) ) then
   do ispin=1,nspin
     write(file_name,'(a,i1,a)') 'rho_',ispin,'.cube'
     open(newunit=ocuberho(ispin),file=file_name)
     write(ocuberho(ispin),'(a)') 'cube file generated from MOLGW'
     write(ocuberho(ispin),'(a,i4)') 'density for spin ',ispin
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') natom,xmin,ymin,zmin
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') nx,dx,0.,0.
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') ny,0.,dy,0.
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') nz,0.,0.,dz
     do iatom=1,natom
       write(ocuberho(ispin),'(i6,4(2x,f12.6))') NINT(zatom(iatom)),0.0,xatom(:,iatom)
     enddo
   enddo
 endif

 do ix=1,nx
   rr(1) = xmin + (ix-1)*dx
   do iy=1,ny
     rr(2) = ymin + (iy-1)*dy
     do iz=1,nz
       rr(3) = zmin + (iz-1)*dz


       call calculate_basis_functions_r(basis,rr,basis_function_r)

       do ispin=1,nspin
         phi(istate1:istate2,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )
       enddo

       !
       ! check whether istate1:istate2 spans all the occupied states
       if( ALL( occupation(istate2+1,:) < completely_empty ) ) then
         do ispin=1,nspin
           write(ocuberho(ispin),'(50(e16.8,2x))') SUM( phi(:,ispin)**2 * occupation(istate1:istate2,ispin) )
         enddo
       endif


       do istate=istate1,istate2
         do ispin=1,nspin
           write(ocubefile(istate,ispin),'(50(e16.8,2x))') phi(istate,ispin)
         enddo
       enddo

     enddo
   enddo
 enddo


 do ispin=1,nspin
   do istate=istate1,istate2
     close(ocubefile(istate,ispin))
   enddo
   close(ocuberho(ispin))
 enddo

 deallocate(phi)
 deallocate(ocubefile)

end subroutine plot_cube_wfn


!=========================================================================
subroutine read_cube_wfn(nstate,basis,occupation,c_matrix)
 use m_definitions
 use m_tools,only: determinant_3x3_matrix
 use m_mpi
 use m_inputparam, only: nspin
 use m_cart_to_pure
 use m_atoms
 use m_basis_set
 use m_dft_grid,only: calculate_basis_functions_r
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: occupation(nstate,nspin)
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
!=====
 integer                    :: icubefile
 character(len=200)         :: file_name,tmp
 real(dp),allocatable       :: phi(:,:),pot(:,:,:)
 real(dp),allocatable       :: pot_i(:,:)
 real(dp)                   :: rr(3)
 real(dp)                   :: xmin,xmax,ymin,ymax,zmin,zmax
 real(dp)                   :: dr(3,3)
 real(dp)                   :: basis_function_r(basis%nbf)
 real(dp)                   :: chi2
 integer                    :: natom1
 integer                    :: nx,ny,nz
 integer                    :: ix,iy,iz
 integer                    :: istate1,istate2,istate,ispin,iatom
 integer,allocatable        :: ocubefile(:,:)
 integer                    :: ocuberho(nspin)
 real(dp)                   :: dv
 integer                    :: stride=6
!=====

 if( .NOT. is_iomaster ) return

 file_name = 'in.cube'
 open(newunit=icubefile,file=TRIM(file_name),action='read',status='old')
 read(icubefile,*) tmp
 read(icubefile,*) tmp
 read(icubefile,*) natom1,xmin,ymin,zmin
 read(icubefile,*) nx,dr(:,1)
 read(icubefile,*) ny,dr(:,2)
 read(icubefile,*) nz,dr(:,3)
 do iatom=1,natom1
   read(icubefile,*)
 enddo
 dv = determinant_3x3_matrix(dr)
 allocate(pot(nx,ny,nz))
 do ix=1,nx
   do iy=1,ny
     do iz=1,(nz/stride-1)*stride+1,stride
       read(icubefile,*) pot(ix,iy,iz:iz+stride-1)
     enddo
     if( modulo(nz,stride) /=0 ) read(icubefile,*) pot(ix,iy,(nz/stride)*stride+1:nz)
   enddo
 enddo
 close(icubefile)
 write(stdout,*) 'normalization:',SUM(pot(:,:,:))*dv

 istate1 = 2
 istate2 = 2

 allocate(phi(istate1:istate2,nspin))
 allocate(pot_i(istate1:istate2,nspin))
 allocate(ocubefile(istate1:istate2,nspin))

 !
 ! check whether istate1:istate2 spans all the occupied states
 if( ALL( occupation(istate2+1,:) < completely_empty ) ) then
   do ispin=1,nspin
     write(file_name,'(a,i1,a)') 'rho_',ispin,'.cube'
     open(newunit=ocuberho(ispin),file=file_name)
     write(ocuberho(ispin),'(a)') 'cube file generated from MOLGW'
     write(ocuberho(ispin),'(a,i4)') 'density for spin ',ispin
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') natom,xmin,ymin,zmin
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') nx,dr(:,1)
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') ny,dr(:,2)
     write(ocuberho(ispin),'(i6,3(f12.6,2x))') nz,dr(:,3)
     do iatom=1,natom
       write(ocuberho(ispin),'(i6,4(2x,f12.6))') NINT(zatom(iatom)),0.0,xatom(:,iatom)
     enddo
   enddo
 endif

 do istate=istate1,istate2
   do ispin=1,nspin
     write(file_name,'(a,i3.3,a,i1,a)') 'wfn_',istate,'_',ispin,'.cube'
     open(newunit=ocubefile(istate,ispin),file=file_name)
     write(ocubefile(istate,ispin),'(a)') 'cube file generated from MOLGW'
     write(ocubefile(istate,ispin),'(a,i4)') 'wavefunction ',istate1
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') natom,xmin,ymin,zmin
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') nx,dr(:,1)
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') ny,dr(:,2)
     write(ocubefile(istate,ispin),'(i6,3(f12.6,2x))') nz,dr(:,3)
     do iatom=1,natom
       write(ocubefile(istate,ispin),'(i6,4(2x,f12.6))') NINT(zatom(iatom)),0.0,xatom(:,iatom)
     enddo
   enddo
 enddo

 pot_i(:,:) = 0.0_dp
 chi2 = 0.0_dp
 do ix=1,nx
   do iy=1,ny
     do iz=1,nz
       rr(1) = xmin
       rr(2) = ymin
       rr(3) = zmin
       rr(:) = rr(:) + (ix-1) * dr(:,1) + (iy-1) * dr(:,2) + (iz-1) * dr(:,3)

       call calculate_basis_functions_r(basis,rr,basis_function_r)

       do ispin=1,nspin
         phi(istate1:istate2,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )
       enddo

       do istate=istate1,istate2
         do ispin=1,nspin
           write(ocubefile(istate,ispin),'(50(en16.8,2x))') phi(istate,ispin)
           pot_i(istate,ispin) = pot_i(istate,ispin) - pot(ix,iy,iz) * phi(istate,ispin)**2 * dv
         enddo
       enddo

       !
       ! check whether istate1:istate2 spans all the occupied states
       if( ALL( occupation(istate2+1,:) < completely_empty ) ) then
         do ispin=1,nspin
           write(ocuberho(ispin),'(50(en16.8,2x))') SUM( phi(:,ispin)**2 * occupation(istate1:istate2,ispin) )
           chi2 = chi2 + ( pot(ix,iy,iz) - SUM( phi(:,ispin)**2 * occupation(istate1:istate2,ispin) ) )**2
         enddo
       endif


     enddo
   enddo
 enddo

 do ispin=1,nspin
   do istate=istate1,istate2
     write(stdout,*) 'FBFB',ispin,istate,pot_i(istate,ispin) * Ha_eV
     close(ocubefile(istate,ispin))
   enddo
   write(stdout,*) 'FBFB chi2',SQRT(chi2) * dv
   close(ocuberho(ispin))
 enddo

 deallocate(phi,pot,pot_i)
 deallocate(ocubefile)

end subroutine read_cube_wfn


!=========================================================================
subroutine read_gaussian_fchk(basis,p_matrix_out)
 use m_definitions
 use m_mpi
 use m_basis_set
 use m_inputparam
 implicit none

 type(basis_set),intent(in) :: basis
 real(dp),intent(out) :: p_matrix_out(basis%nbf,basis%nbf,nspin)
!=====
 character(len=64),parameter :: file_name='gaussian.fchk'
 integer,parameter :: stride=5
 logical :: file_exists,found
 integer :: fu
 integer :: istat
 integer :: ispin,ibf,jbf,ijbf
 integer :: nel
 integer :: block_d(6,6)
 integer :: block_f(10,10)
 integer :: block_g(15,15)
 real(dp) :: swap(basis%nbf,basis%nbf)
 real(dp),allocatable :: p_matrix_read(:)
 character(len=256) :: line
 character(len=100) :: keyword
!=====

 p_matrix_out(:,:,:) = 0.0_dp

 if( .NOT. is_iomaster ) return

 if( nspin /= 1 ) then
   write(stdout,*) 'read_gaussian_fchk: unrestricted calculations not coded yet'
   return
 endif

 if( basis%gaussian_type /= 'CART' ) then
   write(stdout,*) 'read_gaussian_fchk: Pure gaussians not coded yet'
   return
 endif

 select case(TRIM(read_fchk))
 case('SCF')
   keyword = 'Total SCF Density'
 case('CC')
   keyword = 'Total CC Density'
 case('MP2')
   keyword = 'Total MP2 Density'
 case default
   write(stdout,*) 'Unknown density type in read_fchk'
   return
 end select

 write(stdout,'(/,1x,a,a)') 'Reading an existing Gaussian formatted checkpoint point: ',&
                            TRIM(file_name)
 inquire(file=file_name,exist=file_exists)
 if( .NOT. file_exists) then
   write(stdout,*) 'File not found:',TRIM(file_name)
   return
 endif

 write(stdout,'(1x,a,a)') 'Density matrix read: ',TRIM(read_fchk)

 nel = (basis%nbf*(basis%nbf+1))/2
 allocate(p_matrix_read(nel))


 open(newunit=fu,file=TRIM(file_name),status='old',action='read')

 ! Read the fchk file until the keyword is found
 found = .FALSE.
 do while( .NOT. found )
   read(fu,'(a)',iostat=istat) line
   if( IS_IOSTAT_END(istat) ) then
     call issue_warning(TRIM(keyword)//' not found in file')
     return
   endif
   found = ( INDEX(line,TRIM(keyword)) /= 0 )
 enddo

 do ispin=1,nspin
   do ijbf=1,(nel/stride-1)*stride+1,stride
     read(fu,*) p_matrix_read(ijbf:ijbf+stride-1)
   enddo
   if( modulo(nel,stride) /=0 ) read(fu,*) p_matrix_read((nel/stride)*stride+1:nel)
   ijbf = 0
   do ibf=1,basis%nbf
     do jbf=1,ibf
       ijbf = ijbf + 1
       p_matrix_out(ibf,jbf,ispin) = p_matrix_read(ijbf)
       p_matrix_out(jbf,ibf,ispin) = p_matrix_read(ijbf)
     enddo
   enddo
 enddo
 close(fu)


 ! Reorder the basis functions from Gaussian to Libint convention
 ! s and p orbitals are unchanged
 ! gaussian d orbital order is xx, yy, zz, xy, yz, xz
 ! libint   d orbital order is xx, xy, xz, yy, yz, zz

 block_d(:,:) = RESHAPE( [ 1, 0, 0, 0, 0, 0, &
                           0, 0, 0, 1, 0, 0, &
                           0, 0, 0, 0, 1, 0, &
                           0, 1, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 1, &
                           0, 0, 1, 0, 0, 0 ] , [ 6, 6 ] )

 block_f(:,:) = RESHAPE( [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, &    !OK
                           0, 0, 0, 0, 1, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 1, 0, 0, 0, 0, &
                           0, 0, 0, 1, 0, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 1, &
                           0, 0, 0, 0, 0, 0, 1, 0, 0, 0, &
                           0, 1, 0, 0, 0, 0, 0, 0, 0, 0, &    !OK
                           0, 0, 0, 0, 0, 0, 0, 0, 1, 0, &
                           0, 0, 0, 0, 0, 0, 0, 1, 0, 0, &
                           0, 0, 1, 0, 0, 0, 0, 0, 0, 0 ] , [ 10, 10 ] )    !OK

 block_g(:,:) = RESHAPE( [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, &
                           0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, &
                           0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, &
                           0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, &
                           0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, &
                           0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ] , [ 15, 15 ] )

 swap(:,:) = 0.0_dp
 ibf = 1
 do while( ibf <= basis%nbf )
   select case(basis%bfc(ibf)%am)
   case(0)
     swap(ibf,ibf) = 1.0_dp
   case(1)
     swap(ibf  ,ibf  ) = 1.0_dp
     swap(ibf+1,ibf+1) = 1.0_dp
     swap(ibf+2,ibf+2) = 1.0_dp
   case(2)
     swap(ibf:ibf+5,ibf:ibf+5) = block_d(:,:)
   case(3)
     swap(ibf:ibf+9,ibf:ibf+9) = block_f(:,:)
   case(4)
     swap(ibf:ibf+14,ibf:ibf+14) = block_g(:,:)
   case default
     call die('read_gaussian_fchk: too high angular momentum, not coded yet')
   end select
   ibf = ibf + number_basis_function_am('CART',basis%bfc(ibf)%am)
 enddo

 p_matrix_out(:,:,1) = MATMUL( TRANSPOSE(swap), MATMUL(p_matrix_out(:,:,1),swap) )




 deallocate(p_matrix_read)

end subroutine read_gaussian_fchk


!=========================================================================
subroutine write_energy_qp(nstate,energy_qp)
 use m_definitions
 use m_mpi
 use m_inputparam,only: nspin
 implicit none

 integer,intent(in)  :: nstate
 real(dp),intent(in) :: energy_qp(nstate,nspin)
!=====
 integer           :: energy_qpfile
 integer           :: istate
!=====

 !
 ! Only the proc iomaster writes down the ENERGY_QP file
 if( .NOT. is_iomaster) return

 write(stdout,'(/,a)') ' Writing ENERGY_QP file'


 open(newunit=energy_qpfile,file='ENERGY_QP',form='formatted')

 write(energy_qpfile,*) nspin
 write(energy_qpfile,*) nstate
 do istate=1,nstate
   write(energy_qpfile,*) istate,energy_qp(istate,:)
 enddo

 close(energy_qpfile)


end subroutine write_energy_qp


!=========================================================================
subroutine read_energy_qp(nstate,energy_qp,reading_status)
 use m_definitions
 use m_mpi
 use m_warning,only: issue_warning
 use m_inputparam,only: nspin
 implicit none

 integer,intent(in)   :: nstate
 integer,intent(out)  :: reading_status
 real(dp),intent(out) :: energy_qp(nstate,nspin)
!=====
 integer           :: energy_qpfile
 integer           :: istate,jstate
 integer           :: nspin_read,nstate_read
 logical           :: file_exists_capitalized,file_exists
!=====

 write(stdout,'(/,a)') ' Reading ENERGY_QP file'

 inquire(file='ENERGY_QP',exist=file_exists_capitalized)
 inquire(file='energy_qp',exist=file_exists)

 if(file_exists_capitalized) then
   open(newunit=energy_qpfile,file='ENERGY_QP',form='formatted',status='old')
 else if(file_exists) then
   open(newunit=energy_qpfile,file='energy_qp',form='formatted',status='old')
 endif

 if( file_exists_capitalized .OR. file_exists ) then
   read(energy_qpfile,*) nspin_read
   read(energy_qpfile,*) nstate_read
   if( nstate_read /= nstate .OR. nspin_read /= nspin ) then
     call issue_warning('ENERGY_QP file does not have the correct dimensions')
     reading_status=2
   else
     do istate=1,nstate
       read(energy_qpfile,*) jstate,energy_qp(istate,:)
       ! Scissor operator
       if( jstate == -1 ) then
         reading_status=-1
         close(energy_qpfile)
         return
       endif
     enddo
     reading_status=0
   endif
   close(energy_qpfile)
 else
   reading_status=1
   call issue_warning('files ENERGY_QP and energy_qp do not exist')
 endif


end subroutine read_energy_qp


!=========================================================================
subroutine evaluate_wfn_r(nspin,nstate,basis,c_matrix,istate1,istate2,ispin,rr,wfn_i)
 use m_definitions
 use m_basis_set
 use m_dft_grid,only: calculate_basis_functions_r
 implicit none
 integer,intent(in)         :: nspin
 type(basis_set),intent(in) :: basis
 integer,intent(in)         :: nstate
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
 integer,intent(in)         :: istate1,istate2,ispin
 real(dp),intent(in)        :: rr(3)
 real(dp),intent(out)       :: wfn_i(istate1:istate2)
!=====
 real(dp)                   :: basis_function_r(basis%nbf)
!=====

 ! First precalculate all the needed basis function evaluations at point rr
 call calculate_basis_functions_r(basis,rr,basis_function_r)

 ! Then rotate
 wfn_i(istate1:istate2) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )


end subroutine evaluate_wfn_r


!=========================================================================
function wfn_parity(nstate,basis,c_matrix,istate,ispin)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_basis_set
 use m_inputparam
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
 integer,intent(in)         :: istate,ispin
 integer                    :: wfn_parity
!=====
 real(dp) :: phi_tmp1(1),phi_tmp2(1),xtmp(3)
!=====

 xtmp(1) = xcenter(1) +  2.0_dp
 xtmp(2) = xcenter(2) +  1.0_dp
 xtmp(3) = xcenter(3) +  3.0_dp
 call evaluate_wfn_r(nspin,nstate,basis,c_matrix,istate,istate,ispin,xtmp,phi_tmp1)
 xtmp(1) = xcenter(1) -  2.0_dp
 xtmp(2) = xcenter(2) -  1.0_dp
 xtmp(3) = xcenter(3) -  3.0_dp
 call evaluate_wfn_r(nspin,nstate,basis,c_matrix,istate,istate,ispin,xtmp,phi_tmp2)

 if( ABS(phi_tmp1(1) - phi_tmp2(1))/ABS(phi_tmp1(1)) < 1.0e-6_dp ) then
   wfn_parity = 1
 else
   wfn_parity = -1
 endif


end function wfn_parity


!=========================================================================
function wfn_reflection(nstate,basis,c_matrix,istate,ispin)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_basis_set
 use m_inputparam
 implicit none
 integer,intent(in)         :: nstate
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,nstate,nspin)
 integer,intent(in)         :: istate,ispin
 integer                    :: wfn_reflection
!=====
 real(dp) :: phi_tmp1(1),phi_tmp2(1)
 real(dp) :: xtmp1(3),xtmp2(3)
 real(dp) :: proj
!=====

 xtmp1(1) = xatom(1,1) +  2.0_dp
 xtmp1(2) = xatom(2,1) +  1.0_dp
 xtmp1(3) = xatom(3,1) +  3.0_dp
 call evaluate_wfn_r(nspin,nstate,basis,c_matrix,istate,istate,ispin,xtmp1,phi_tmp1)

 proj = DOT_PRODUCT( xtmp1 , xnormal )
 xtmp2(:) = xtmp1(:) -  2.0_dp * proj * xnormal(:)
 call evaluate_wfn_r(nspin,nstate,basis,c_matrix,istate,istate,ispin,xtmp2,phi_tmp2)

 if( ABS(phi_tmp1(1) - phi_tmp2(1))/ABS(phi_tmp1(1)) < 1.0e-6_dp ) then
   wfn_reflection = 1
 else if( ABS(phi_tmp1(1) + phi_tmp2(1))/ABS(phi_tmp1(1)) < 1.0e-6_dp ) then
   wfn_reflection = -1
 else
   wfn_reflection = 0
 endif


end function wfn_reflection


!=========================================================================
